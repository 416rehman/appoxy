use std::fs::File;
use std::io::Write;
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
    pub fn save(&self, app_id: &str) -> Result<(), Box<dyn std::error::Error>> {
        // dump this builder to /app/<app_id>/builder.toml, if it exists already, overwrite it
        let mut file = File::create(format!("/app/{}/builder.toml", app_id))?;
        file.write_all(toml::to_string(self)?.as_bytes())?;
        Ok(())
    }

    // Runs "pack builder create <app_id>:<stack.id> --config /app/<app_id>/builder.toml" and return handle to the process
    pub async fn run_create(&self, app_id: i64) -> Result<tokio::process::Child, std::io::Error> {
        tokio::process::Command::new("pack")
            .arg("builder")
            .arg("create")
            .arg(format!("{}:{}", app_id, self.stack.id))
            .arg("--config")
            .arg(format!("/app/{}/builder.toml", app_id))
            .stdout(std::process::Stdio::piped())
            .stderr(std::process::Stdio::piped())
            .spawn()
    }
}
