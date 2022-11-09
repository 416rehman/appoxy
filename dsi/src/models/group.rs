use rocket::serde::{Deserialize, Serialize};

#[derive(Default, Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
#[serde(crate = "rocket::serde")]
pub struct Group {
    pub id: Option<String>,
    pub optional: Option<bool>,
}

// [[order.group]]
//     id = "samples/hello-moon"
//     version = "0.0.1"