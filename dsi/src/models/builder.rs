use rocket::serde::{Deserialize, Serialize};

#[derive(Default, Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
#[serde(crate = "rocket::serde")]
pub struct Builder {
    pub description: String,
    pub stack: Stack,
    pub lifecycle: Lifecycle,
    pub buildpacks: Vec<Buildpack>,
    pub order: Vec<Order>,
}

#[derive(Default, Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
#[serde(crate = "rocket::serde")]
pub struct Stack {
    pub id: String,
    #[serde(rename = "build-image")]
    pub build_image: String,
    #[serde(rename = "run-image")]
    pub run_image: String,
}

#[derive(Default, Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
#[serde(crate = "rocket::serde")]
pub struct Lifecycle {
    pub version: String,
}

#[derive(Default, Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
#[serde(crate = "rocket::serde")]
pub struct Buildpack {
    pub id: Option<String>,
    pub uri: String,
}

#[derive(Default, Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
#[serde(crate = "rocket::serde")]
pub struct Order {
    pub group: Vec<Group>,
}

#[derive(Default, Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
#[serde(crate = "rocket::serde")]
pub struct Group {
    pub id: String,
    pub version: String,
    pub optional: Option<bool>,
}


impl Builder {

    pub async fn create(&self, user_id: i64, app_id: i64) -> Result<(), String> {
        // Runs "pack builder create <user_id>:<app_id> --config <path/to/this_builder.toml>"

        // dump this builder to a toml file in a temp directory


        let mut cmd = std::process::Command::new("pack");
        cmd.arg("builder");
        cmd.arg("create");






        Ok(())
    }
}
