#[macro_use] extern crate rocket;

mod routers;
mod models;
mod integration_tests;
mod utility;

#[get("/")]
fn index() -> &'static str {
    "Hello, world!"
}

#[launch]
fn rocket() -> _ {
    rocket::build().mount("/", routes![index, routers::droids_router::new, routers::stacks_router::common])
}
