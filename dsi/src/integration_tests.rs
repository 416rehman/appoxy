use super::rocket;
use rocket::local::blocking::Client;
use rocket::http::Status;
use rocket::serde::json::serde_json;


#[test]
fn droid_creation() {
    println!("Sending POST data with buildpacks [\"heroku/ruby\", \"heroku/nodejs\"] to /droids should return 200 OK and stream the output of the buildpacks");

    let client = Client::tracked(rocket()).expect("valid rocket instance");
    let response = client.post(uri!(super::routers::droids_router::new))
        .body(r#"{"app_id": 1,"repo": "github.com/rocket","branch": "main","buildpacks": [{"uri": "heroku/nodejs"}],"env": ["FOO=bar", "BAZ=qux"],"stack": {"id": "heroku-18","build-image": "heroku/buildpacks:20","run-image": "heroku/pack:20"}}"#)
    .dispatch();

    assert_eq!(response.status(), Status::Ok);
    //
    // let response = response.into_string().unwrap();
    // let response_data: serde_json::Value = serde_json::from_str(&response).unwrap();
    // assert_eq!(response_data["message"], "Droid created");
}

#[test]
fn common_stack_detection() {
    println!("Sending POST body with the vector [\"heroku/ruby\", \"heroku/nodejs\"] to /stacks/common should return 200 OK and common stacks [\"heroku-18\", \"heroku-20\"]");

    let client = Client::tracked(rocket()).expect("valid rocket instance");
    let response = client.post(uri!(super::routers::stacks_router::common))
        .body(r#"[{"uri": "heroku/nodejs"}, {"uri":"heroku/ruby"}, {"uri":"paketo-buildpacks/java"}]"#)
    .dispatch();
    assert_eq!(response.status(), Status::Ok);

    let response = response.into_string().unwrap();
    let response_data: serde_json::Value = serde_json::from_str(&response).unwrap();
    assert_eq!(response_data["message"], "Common stacks detected");

    let common_stacks = response_data["data"]["common_stacks"].as_array().unwrap();
    let expected_common_stacks = vec!["heroku-18", "heroku-20"];
    assert_eq!(common_stacks, &expected_common_stacks);
}