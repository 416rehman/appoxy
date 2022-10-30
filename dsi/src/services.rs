use rocket::serde::json::{serde_json, Value};

pub async fn detect_common_stacks(buildpack_list: &Vec<String>) -> Result<Vec<String>, String> {
    let url = "https://cnb-registry-api-staging.herokuapp.com//api/v1/buildpacks/".to_string();

    // if buildpack is urn:cnb:registry:paketo-buildpacks/java or paketo-buildpacks/java@7.9.0, then return paketo-buildpacks/java
    let buildpacks = buildpack_list.iter().map(|buildpack| {
        let buildpack = buildpack.replace("urn:cnb:registry:", "");
        let buildpack = buildpack.split("@").collect::<Vec<&str>>()[0];
        buildpack.to_string()
    }).collect::<Vec<String>>();

    let mut common_stacks = Vec::new();

    'buildpacks: for (i, buildpack) in buildpacks.iter().enumerate() {
        let buildpack_url = url.clone() + &buildpack;

        let response = reqwest::get(&buildpack_url).await.unwrap();

        let response: Value = serde_json::from_str(&response.text().await.unwrap()).unwrap();
        let stacks = response["latest"]["stacks"].as_array().expect("failed to get stacks");

        if i == 0 {
            common_stacks = stacks.to_vec();
        } else {
            // uf the common_stacks is a wildcard, then set it to the current stacks
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
                return Err("no common stack".to_string());
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
