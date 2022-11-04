use std::fs::File;
use std::io::Write;
use rocket::serde::{Deserialize, Serialize};
use crate::models::buildpack::Buildpack;
use crate::models::order::Order;
use crate::models::stack::Stack;

// https://buildpacks.io/docs/reference/config/builder-config
#[derive(Default, Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
#[serde(crate = "rocket::serde")]
pub struct Builder {
    pub description: Option<String>,
    pub stack: Stack,
    pub buildpacks: Vec<Buildpack>,
    pub order: Vec<Order>,
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
