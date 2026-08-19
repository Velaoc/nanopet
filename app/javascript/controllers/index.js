// Register all controllers. Foundation controllers are lazy-loaded by name;
// the NanoPet panel controller is eager so the reaction animations replay.
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
import PetController from "controllers/pet_controller"

eagerLoadControllersFrom("controllers", application)
application.register("pet", PetController)
