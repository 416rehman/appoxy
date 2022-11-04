use std::fmt::format;
use rocket::serde::json::{Value};
use crate::models::buildpack;
use crate::models::buildpack::Buildpack;
use crate::utility::buildpack::fetch_buildpack_info;

pub async fn detect_common_stacks(buildpack_list: &Vec<Buildpack>) -> Result<Vec<String>, Box<dyn std::error::Error>> {
    let mut common_stacks = Vec::new();

    'buildpacks: for (i, bp) in buildpack_list.iter().enumerate() {
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

#[test]
fn test_detect_common_stacks() {
    println!("Providing heroku/nodejs and heroku/ruby as buildpacks should detect heroku-18 and heroku-20 as common stacks");
    let buildpacks = vec![
        Buildpack {
            id: Some("heroku/nodejs".to_string()),
            uri: "heroku/nodejs".to_string(),
        },
        Buildpack {
            id: Some("heroku/ruby".to_string()),
            uri: "heroku/ruby".to_string(),
        },
        Buildpack {
            id: Some("paketo-buildpacks/java".to_string()),
            uri: "paketo-buildpacks/java".to_string(),
        },
    ];
    let common_stacks = tokio_test::block_on(detect_common_stacks(&buildpacks)).unwrap();
    assert_eq!(common_stacks, vec!["heroku-18", "heroku-20"]);
}