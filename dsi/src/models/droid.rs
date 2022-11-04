use rocket::serde::{Deserialize, Serialize};
use crate::utility::stack::detect_common_stacks;
use crate::models::builder;
use crate::models::buildpack::Buildpack;
use crate::models::group::Group;
use crate::models::order::Order;
use crate::models::stack::Stack;

#[derive(Debug, Serialize, Deserialize)]
#[serde(crate = "rocket::serde")]
pub struct Droid {
    app_id: i64,
    repo: String,
    branch: String,
    buildpacks: Vec<Buildpack>,
    env: Vec<String>,
    stack: Stack,
}

impl Droid {
    pub async fn detect_common_stacks(&self) -> Result<Vec<String>, Box<dyn std::error::Error>> {
        detect_common_stacks(&self.buildpacks).await
    }

    pub async fn create_builder(&self) -> Result<builder::Builder, String> {
        let builder = builder::Builder{
            buildpacks: self.buildpacks.clone(),
            stack: self.stack.clone(),
            description: Some("Created by Droid".to_string()),
            order: self.buildpacks.iter().map(|buildpack| Order{
                group: vec![Group {
                    id: buildpack.id.clone().unwrap(),
                    optional:
                }]
            }).collect::<Vec<Order>>()
        };

        Ok(builder)
    }
}
