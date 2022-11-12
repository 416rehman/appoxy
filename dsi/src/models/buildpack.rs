use rocket::futures::future::err;
use rocket::serde::{Deserialize, Serialize};
use crate::utility::buildpack::fetch_buildpack_info;

#[derive(Default, Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
#[serde(crate = "rocket::serde")]
pub struct Buildpack {
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
    pub fn from_uri(uri: &str) -> Result<Buildpack, Box<dyn std::error::Error>> {
        let buildpack = Buildpack {
            uri: uri.to_string(),
            ..Default::default()
        };

        Ok(buildpack)
    }

    pub fn id(&self) -> Result<String, Box<dyn std::error::Error>> {
        Ok(self.uri.split('@').collect::<Vec<&str>>()[0].split(':').collect::<Vec<&str>>().last().unwrap().to_string())
    }

    /// Fetches the buildpack info from the registry, and sets the version and compatible stacks fields.
    /// If no version is found or no compatible stacks are found, then an error is returned.
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
                        if v["version"] == version.as_str() {
                            found = true;
                            break;
                        }
                    }
                    // if not in the list, set self.version to the latest version
                    if !found {
                        println!("Version {} not found for buildpack {}", version, self.uri);
                        println!("Setting version to latest version");
                        self.version = Some(match versions[0]["version"].as_str() {
                            Some(v) => v.to_string(),
                            None => return Err("No version found".into())
                        });
                    }
                } else {
                    // if self.version is not provided, set it to the latest version
                    self.version = Some(match versions[0]["version"].as_str() {
                        Some(v) => v.to_string(),
                        None => return Err("No version found".into())
                    });
                }
                println!("Using version {}", self.version.clone().unwrap());
            }
            None => return Err("Failed to fetch versions info from registry".into())
        }

        // data["latest"]["stacks"] as array of strings
        match data["latest"]["stacks"].as_array() {
            Some(stacks) => {
                self.compatible_stacks = Some(stacks.iter().map(|s| {
                    match s.as_str() {  // as_str() removes the quotes from the json string value
                        Some(s) => s.to_string(),   // convert &str to String
                        None => "".to_string()  // if s.as_str() is None, return an empty string
                    }
                }).collect());
            }
            None => return Err(format!("Buildpack {} does not have any compatible stacks", self.uri).into())
        }

        Ok(())
    }
}