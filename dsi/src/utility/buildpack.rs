use rocket::serde::json::{serde_json, Value};

pub async fn fetch_buildpack_info(buildpack: &String) -> Result<Value, String> {
    let buildpack_url = "https://cnb-registry-api-staging.herokuapp.com//api/v1/buildpacks/".to_string() + buildpack;

    let response = match reqwest::get(&buildpack_url).await {
        Ok(response) => response,
        Err(err) => return Err(format!("Error fetching buildpack info: {}", err))
    };

    let response = match response.text().await {
        Ok(response) => response,
        Err(err) => return Err(format!("Error getting buildpack info: {}", err))
    };

    let response = match serde_json::from_str(&response) {
        Ok(response) => response,
        Err(err) => return Err(format!("Error parsing buildpack info: {}", err))
    };

    Ok(response)
}

#[test]
fn test_fetch_buildpack_info() {
    println!("Fetched info for buildpack paketo-buildpacks/java should be a json object, with 'stacks' array");
    let buildpack = "paketo-buildpacks/java".to_string();
    let response = tokio_test::block_on(fetch_buildpack_info(&buildpack));
    assert!(response.is_ok());
    let response = response.unwrap();
    assert!(response["latest"]["stacks"].is_array());
}