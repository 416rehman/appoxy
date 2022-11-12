use rocket::serde::{Deserialize, Serialize};
use crate::models::buildpack::Buildpack;

#[derive(Default, Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(crate = "rocket::serde")]
pub struct Stack {
    pub id: String,
    #[serde(rename = "build-image")]
    pub build_image: String,
    #[serde(rename = "run-image")]
    pub run_image: String,
}

// [stack]
// id = "io.buildpacks.samples.stacks.bionic"
// run-image = "cnbs/sample-stack-run:bionic"
// build-image = "cnbs/sample-stack-build:bionic"

impl Stack {
    /// Detects the common stacks for the buildpacks in the provided buildpacks vector.
    /// NOTE: If the buildpacks are not validated (i.e. the version and compatible stacks are not set), they will be validated here.
    pub async fn detect_common_stacks(buildpack_list: &mut Vec<Buildpack>) -> Result<Vec<String>, Box<dyn std::error::Error>> {
        let mut common_stacks = Vec::new();

        'buildpacks: for (i, bp) in buildpack_list.iter_mut().enumerate() {
            if bp.version.is_none() || bp.compatible_stacks.is_none() {
                bp.validate().await?;
            }
            let compatible_stacks = match &bp.compatible_stacks {
                Some(stacks) => stacks,
                None => {
                    return Err(format!("Buildpack {} does not have any compatible stacks", bp.uri).into());
                }
            };

            if i == 0 {
                common_stacks = compatible_stacks.clone();
            } else {
                // if the common_stacks is a wildcard, then set it to the current stacks
                if common_stacks.contains(&"*".to_string()) {
                    common_stacks = compatible_stacks.clone();
                    continue 'buildpacks;
                }
                let mut matching_stacks: Vec<String> = Vec::new();
                for stack in compatible_stacks {
                    println!("{}", stack);
                    // if stack is wildcard, then skip this buildpack
                    if stack == "*" {
                        continue 'buildpacks;
                    }
                    if common_stacks.contains(&stack) {
                        matching_stacks.push(stack.clone());
                    }
                }

                if matching_stacks.is_empty() {
                    return Err(format!("No common stacks found for buildpack {}", bp.uri).into());
                }

                common_stacks = matching_stacks;
            }
        }

        if common_stacks.is_empty() {
            return Err("No common stacks found".into());
        }

        Ok(common_stacks)
    }
}

#[test]
fn test_detect_common_stacks() {
    println!("Providing heroku/nodejs and heroku/ruby as buildpacks should detect heroku-18 and heroku-20 as common stacks");
    let mut buildpacks = vec![
        Buildpack::from_uri("heroku/nodejs").unwrap(),
        Buildpack::from_uri("heroku/ruby").unwrap(),
    ];
    if let Ok(stacks) = tokio_test::block_on(Stack::detect_common_stacks(&mut buildpacks)) {
        assert!(stacks.contains(&"heroku-18".to_string()));
        assert!(stacks.contains(&"heroku-20".to_string()));
    }
    // assert_eq!(common_stacks, vec!["heroku-18", "heroku-20"]);
}