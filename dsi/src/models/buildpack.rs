use rocket::serde::{Deserialize, Serialize};
use crate::utility::buildpack::fetch_buildpack_info;

#[derive(Default, Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
#[serde(crate = "rocket::serde")]
pub struct Buildpack {
    pub id: Option<String>,
    pub uri: String,
    pub version: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub optional: Option<bool>,
    #[serde(skip)]
    pub compatible_stacks: Option<Vec<String>>,
}

// [[buildpacks]]
// uri = "samples/buildpacks/hello-processes"

impl Buildpack {
    pub async fn validate(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let data = fetch_buildpack_info(
            &self.uri.replace("urn:cnb:registry:", "")
                .split("@").collect::<Vec<&str>>()[0].to_string()
        ).await?;

        match data["versions"].as_array() {
            Some(versions) => {
                if versions.len() == 0 {
                    return Err("No versions found".into());
                }
                // check if self.version is in versions
                if self.version.is_some() {
                    let version = self.version.clone().unwrap();
                    let mut found = false;
                    // check if the provided version is in the list of versions
                    for v in versions {
                        if v["version"] == version {
                            found = true;
                            break;
                        }
                    }
                    // if not in the list, set self.version to the latest version
                    if !found {
                        println!("Version {} not found for buildpack {}", version, self.uri);
                        println!("Setting version to latest version");
                        self.version = Some(versions[0]["version"].to_string());
                    }
                } else {
                    // if self.version is not provided, set it to the latest version
                    self.version = Some(versions[0]["version"].to_string());
                }
                println!("Using version {}", self.version.clone().unwrap());
            }
            None => return Err("Failed to fetch versions info from registry".into())
        }

        // validate the stack
        match data["latest"]["stacks"].as_array() {
            Some(stacks) => stacks,
            None => return Err(format!("Buildpack {} does not have any compatible stacks", self.uri).into())
        };

        println!("Buildpack {} is valid", self.uri);
        Ok(())
    }
}