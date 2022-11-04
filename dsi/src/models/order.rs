use rocket::serde::{Deserialize, Serialize};
use crate::models::group::Group;

#[derive(Default, Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
#[serde(crate = "rocket::serde")]
pub struct Order {
    pub group: Vec<Group>,
}

// [[order]]
//     [[order.group]]
//     id = "samples/hello-world"
//     version = "0.0.1"