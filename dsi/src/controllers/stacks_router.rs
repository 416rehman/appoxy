use rocket::http::Status;
use rocket::response::status;
use rocket::serde::json::Json;
use crate::services::detect_common_stacks;

#[post("/stacks/common", data="<buildpacks>")]
pub async fn common(buildpacks: Json<Vec<String>>) -> status::Custom<Json<Vec<String>>> {
    println!("buildpacks: {:?}", buildpacks);
    let common_stacks = detect_common_stacks(&buildpacks).await;
    if let Ok(stacks) = common_stacks {
        println!("Common stacks: {:?}", stacks);
        status::Custom(Status::Ok, Json(stacks))
    } else {
        status::Custom(Status::BadRequest, Json(vec![]))
    }
}
