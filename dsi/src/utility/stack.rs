use rocket::serde::json::{Value};
use crate::utility::buildpack::fetch_buildpack_info;

pub async fn detect_common_stacks(buildpack_list: &Vec<String>) -> Result<Vec<String>, String> {
    // if buildpack is urn:cnb:registry:paketo-buildpacks/java or paketo-buildpacks/java@7.9.0, then extract paketo-buildpacks/java
    let buildpacks = buildpack_list.iter().map(|buildpack| {
        let buildpack = buildpack.replace("urn:cnb:registry:", "");
        let buildpack = buildpack.split("@").collect::<Vec<&str>>()[0];
        buildpack.to_string()
    }).collect::<Vec<String>>();

    let mut common_stacks = Vec::new();

    'buildpacks: for (i, buildpack) in buildpacks.iter().enumerate() {
        let bp_info = fetch_buildpack_info(buildpack).await?;

        let stacks = match bp_info["latest"]["stacks"].as_array() {
            Some(stacks) => stacks,
            None => return Err("Missing stacks in buildpack info for buildpack: ".to_string() + buildpack)
        };

        if i == 0 {
            common_stacks = stacks.to_vec();
        } else {
            // if the common_stacks is a wildcard, then set it to the current stacks
            if common_stacks.contains(&Value::String("*".to_string())) {
                common_stacks = stacks.to_vec();
                continue 'buildpacks;
            }
            let mut matching_stacks: Vec<Value> = Vec::new();
            for stack in stacks {
                // if stack is wildcard, then skip this buildpack
                if stack == "*" {
                    continue 'buildpacks;
                }
                if common_stacks.contains(&stack) {
                    matching_stacks.push(stack.clone());
                }
            }

            if matching_stacks.is_empty() {
                return Err("No common stacks found when detecting common stacks for buildpack: ".to_string() + &buildpack);
            }

            common_stacks = matching_stacks;
        }
    }

    if common_stacks.is_empty() {
        return Err("no common stack found".to_string());
    }

    let common_stacks = common_stacks.iter().map(|stack| {
        stack.as_str().unwrap().to_string()
    }).collect::<Vec<String>>();

    Ok(common_stacks)
}

#[test]
fn test_detect_common_stacks() {
    println!("Providing heroku/nodejs and heroku/ruby as buildpacks should detect heroku-18 and heroku-20 as common stacks");
    let buildpacks = vec!["heroku/nodejs".to_string(), "heroku/ruby".to_string(), "paketo-buildpacks/java".to_string()];
    let common_stacks = tokio_test::block_on(detect_common_stacks(&buildpacks)).unwrap();
    assert_eq!(common_stacks, vec!["heroku-18", "heroku-20"]);
}