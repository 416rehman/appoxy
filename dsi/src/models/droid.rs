use rocket::serde::{Deserialize, Serialize};
use crate::models::builder;
use crate::models::buildpack::Buildpack;
use crate::models::group::Group;
use crate::models::order::Order;
use crate::models::stack::Stack;

#[derive(Debug, Serialize, Deserialize)]
#[serde(crate = "rocket::serde")]
pub struct Droid {
    pub app_id: i64,
    repo: String,
    branch: String,
    buildpacks: Vec<Buildpack>,
    env: Vec<String>,
    pub stack: Stack, // Stack to be used for the builder, use the detect_common_stacks function to find a compatible stack for the buildpacks
}

impl Droid {
    pub async fn detect_common_stacks(&mut self) -> Result<Vec<String>, Box<dyn std::error::Error>> {
        Stack::detect_common_stacks(&mut self.buildpacks).await
    }

    pub async fn create_builder(&self) -> Result<builder::Builder, String> {
        let builder = builder::Builder{
            buildpacks: self.buildpacks.clone(),
            stack: self.stack.clone(),
            description: Some("Created by Droid".to_string()),
            order: self.buildpacks.iter().map(|buildpack| Order{
                group: vec![Group {
                    id: buildpack.id.clone(),
                    optional: buildpack.optional
                }]
            }).collect::<Vec<Order>>()
        };

        Ok(builder)
    }
}
