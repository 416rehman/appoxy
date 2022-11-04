use rocket::serde::{Deserialize, Serialize};

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

// [stack]
// id = "io.buildpacks.samples.stacks.bionic"
// run-image = "cnbs/sample-stack-run:bionic"
// build-image = "cnbs/sample-stack-build:bionic"