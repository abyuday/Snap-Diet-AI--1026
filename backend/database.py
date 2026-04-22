import os
from motor.motor_asyncio import AsyncIOMotorClient

# Get MONGO_URL from env or use default for local testing
MONGO_DETAILS = os.getenv("MONGO_URL", "mongodb://admin:adminpassword@localhost:27017")

client = AsyncIOMotorClient(MONGO_DETAILS)
database = client.dietitian_db

user_collection = database.get_collection("users")
history_collection = database.get_collection("history")

# Helper function to parse database objects
def user_helper(user) -> dict:
    return {
        "id": str(user["_id"]),
        "name": user["name"],
        "email": user["email"],
        "rank": user.get("rank", "Nutrition Novice"),
        "goals": user.get("goals", {
            "calorieGoal": 2000,
            "proteinGoal": 120,
            "carbsGoal": 250,
            "fatGoal": 70,
            "waterGoal": 2500,
        })
    }
