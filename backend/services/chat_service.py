import os
import re
import json
from typing import List, Dict, Any, Optional
from openai import OpenAI


class ChatService:
    def __init__(self):
        self.api_key = os.getenv("HF_TOKEN") or os.getenv("OPENAI_API_KEY")
        self.base_url = os.getenv("AI_BASE_URL", "https://api.openai.com/v1")
        self.model = os.getenv("AI_MODEL", "gpt-4o")

        if self.api_key:
            self.client = OpenAI(api_key=self.api_key, base_url=self.base_url)
        else:
            self.client = None

    # ------------------------------------------------------------------
    # Intent detection helpers
    # ------------------------------------------------------------------

    def _detect_logging_intent(self, message: str) -> bool:
        """Returns True if the message sounds like the user is logging a meal."""
        patterns = [
            r'\bi (just |had |ate |consumed |drank |eaten )',
            r'\bi just',
            r'\bfor (breakfast|lunch|dinner|snack)\b',
            r'\bthis morning\b',
            r'\bthis evening\b',
            r'\bjust ate\b',
            r'\bjust had\b',
            r'\bjust drank\b',
        ]
        msg_lower = message.lower()
        return any(re.search(p, msg_lower) for p in patterns)

    def _detect_recipe_intent(self, message: str) -> bool:
        """Returns True if the message asks for a recipe."""
        keywords = [
            'recipe', 'make', 'prepare', 'cook', 'how to make', 'how do i cook',
            'ingredients', 'what can i make', 'what should i cook',
            'suggest a recipe', 'give me a recipe', 'dish using',
        ]
        msg_lower = message.lower()
        return any(k in msg_lower for k in keywords)

    # ------------------------------------------------------------------
    # Recipe generation
    # ------------------------------------------------------------------

    def generate_recipes(self, ingredients_or_query: str,
                         profile: Dict[str, Any],
                         goals: Dict[str, Any]) -> Dict[str, Any]:
        """
        Generates 2-3 tailored Indian/Global recipes from a text description
        of ingredients or a recipe request. Returns structured recipe cards.
        """
        if not self.client:
            return {
                "reply": "Recipe generation requires an API key. Please configure AI_MODEL in your .env file.",
                "recipes": [],
                "recommendations": []
            }

        system_prompt = (
            "You are a world-class chef and dietitian specializing in both Indian and Western cuisine. "
            "When given ingredients or a recipe request, suggest 2-3 fitting recipes. "
            "Your output MUST follow this EXACT format for EACH recipe — no exceptions:\n\n"
            "---RECIPE---\n"
            "Name: [Recipe Name]\n"
            "Emoji: [1 Emoji]\n"
            "Servings: [Number]\n"
            "PrepTime: [e.g. 20 mins]\n"
            "CookTime: [e.g. 30 mins]\n"
            "Calories: [per serving, number only]\n"
            "Protein: [grams, number only]\n"
            "Carbs: [grams, number only]\n"
            "Fat: [grams, number only]\n"
            "Description: [1-2 sentence description]\n"
            "Ingredients:\n"
            "- [ingredient 1]\n"
            "- [ingredient 2]\n"
            "Steps:\n"
            "1. [Step 1]\n"
            "2. [Step 2]\n"
            "---END---\n\n"
            "After ALL recipes, add one short paragraph summary about why these recipes suit the user's goals."
        )

        user_context = (
            f"User goals: {goals.get('daily_calories', 2000)} kcal/day, "
            f"{goals.get('protein_target', 50)}g protein target.\n"
            f"Request: {ingredients_or_query}"
        )

        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_context},
                ],
                temperature=0.8,
                max_tokens=2000
            )
            raw = response.choices[0].message.content
            recipes = self._parse_recipes(raw)

            # Extract summary (text after last ---END---)
            summary = ""
            if "---END---" in raw:
                after = raw.split("---END---")[-1].strip()
                if after:
                    summary = after

            return {
                "reply": summary or "Here are some recipes tailored to your goals!",
                "recipes": recipes,
                "recommendations": []
            }
        except Exception as e:
            return {
                "reply": f"I had trouble generating recipes: {str(e)}",
                "recipes": [],
                "recommendations": []
            }

    def _parse_recipes(self, raw: str) -> List[Dict[str, Any]]:
        """Parse the structured recipe blocks from the AI output."""
        recipes = []
        blocks = re.split(r'---RECIPE---', raw)
        for block in blocks[1:]:
            end_idx = block.find("---END---")
            if end_idx != -1:
                block = block[:end_idx]
            recipe = {}
            lines = block.strip().split('\n')
            mode = None
            ingredients = []
            steps = []

            for line in lines:
                line = line.strip()
                if not line:
                    continue
                if line == "Ingredients:":
                    mode = "ingredients"
                    continue
                if line == "Steps:":
                    mode = "steps"
                    continue

                if mode == "ingredients" and line.startswith("-"):
                    ingredients.append(line[1:].strip())
                    continue
                if mode == "steps" and re.match(r'^\d+\.', line):
                    steps.append(re.sub(r'^\d+\.\s*', '', line))
                    continue

                # Named fields
                if ':' in line:
                    mode = None  # reset mode on named field
                    key, _, val = line.partition(':')
                    key = key.strip().lower()
                    val = val.strip()
                    field_map = {
                        'name': 'name', 'emoji': 'emoji', 'servings': 'servings',
                        'preptime': 'prep_time', 'cooktime': 'cook_time',
                        'calories': 'calories', 'protein': 'protein',
                        'carbs': 'carbs', 'fat': 'fat', 'description': 'description',
                    }
                    if key in field_map:
                        # Try numeric cast for macros
                        if key in ('calories', 'protein', 'carbs', 'fat'):
                            try:
                                recipe[field_map[key]] = float(re.sub(r'[^\d.]', '', val))
                            except ValueError:
                                recipe[field_map[key]] = 0.0
                        else:
                            recipe[field_map[key]] = val

            recipe['ingredients'] = ingredients
            recipe['steps'] = steps
            if recipe.get('name'):
                recipes.append(recipe)

        return recipes

    # ------------------------------------------------------------------
    # Meal logging intent → parse meals from speech
    # ------------------------------------------------------------------

    def parse_logged_meal(self, message: str) -> Dict[str, Any]:
        """
        If the user says 'I just ate two scrambled eggs and toast', extract
        a list of food items with estimated quantities.
        """
        if not self.client:
            return {"foods": [], "raw_message": message}

        system_prompt = (
            "You are a nutrition assistant. The user will describe what they ate in natural language. "
            "Extract the individual food items and quantities. "
            "Output ONLY valid JSON in this exact format:\n"
            '{"foods": [{"name": "Scrambled Eggs", "quantity": 2, "unit": "pieces"}, ...]}\n'
            "Use sensible defaults for quantities if not stated (e.g. 1 bowl, 1 piece). "
            "Do not include anything outside the JSON."
        )

        try:
            resp = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": message},
                ],
                temperature=0.2,
                max_tokens=400,
            )
            content = resp.choices[0].message.content.strip()
            # Extract JSON block
            json_match = re.search(r'\{.*\}', content, re.DOTALL)
            if json_match:
                return json.loads(json_match.group())
            return {"foods": [], "raw_message": message}
        except Exception:
            return {"foods": [], "raw_message": message}

    # ------------------------------------------------------------------
    # Main chat response
    # ------------------------------------------------------------------

    def get_response(self,
                     message: str,
                     profile: Dict[str, Any],
                     history: List[Dict[str, Any]],
                     goals: Dict[str, Any]) -> Dict[str, Any]:
        """
        Routes the message to recipe generation, meal-log parsing, or
        standard dietitian advice depending on detected intent.
        """
        if not self.client:
            return {
                "reply": "I'm currently in offline mode. Please configure an AI API key to start chatting!",
                "recommendations": [],
                "recipes": [],
                "logged_foods": []
            }

        # ── Recipe intent
        if self._detect_recipe_intent(message):
            result = self.generate_recipes(message, profile, goals)
            result["logged_foods"] = []
            return result

        # ── Logging intent → parse meal + still give chat reply
        logged_foods = []
        if self._detect_logging_intent(message):
            parsed = self.parse_logged_meal(message)
            logged_foods = parsed.get("foods", [])

        # ── Standard dietitian chat
        user_context = (
            f"User Profile: {profile.get('name', 'User')}, Rank: {profile.get('rank', 'Novice')}.\n"
            f"Goals: {goals.get('daily_calories', 2000)} kcal, {goals.get('protein_target', 50)}g protein.\n"
        )
        current_cal = sum(item.get('calories', 0) for item in history)
        current_prot = sum(item.get('protein', 0) for item in history)
        user_context += f"Today's Intake so far: {current_cal} kcal, {current_prot}g protein.\n"

        if logged_foods:
            foods_str = ', '.join(f"{f.get('quantity',1)} {f.get('unit','')} {f['name']}" for f in logged_foods)
            user_context += f"User just logged: {foods_str}.\n"

        system_prompt = (
            "You are 'AI Dietitian', a professional, friendly, and highly knowledgeable nutrition expert "
            "who specialises in both Indian cuisine and global foods. "
            "FORMATTING RULES:\n"
            "1. NEVER use markdown tables.\n"
            "2. Use hyphens (-) for bullet points.\n"
            "3. Use bold (**) for categories and food names.\n"
            "4. Use emojis appropriately.\n"
            "5. Be concise, encouraging, and medically grounded.\n"
            "6. NEVER prefix your reply with a name header.\n"
            "CRITICAL: At the very end of your response, provide exactly 2 food recommendations. "
            "Format EXACTLY like this:\n"
            "---RECOMMENDATIONS---\n"
            "Name: [Food Name 1]\nReason: [Short reason]\nEmoji: [1 Emoji]\n---\n"
            "Name: [Food Name 2]\nReason: [Short reason]\nEmoji: [1 Emoji]"
        )

        try:
            messages = [
                {"role": "system", "content": system_prompt},
                {"role": "system", "content": f"User Context: {user_context}"},
                {"role": "user", "content": message},
            ]
            
            print(f"DEBUG [Chat]: Sending request to {self.model} with {len(messages)} messages", flush=True)
            
            response = self.client.chat.completions.create(
                model=self.model,
                messages=messages,
                temperature=0.7
            )

            reply = response.choices[0].message.content
            recommendations = []
            main_reply = reply

            if "---RECOMMENDATIONS---" in reply:
                parts = reply.split("---RECOMMENDATIONS---")
                main_reply = parts[0].strip()
                recs_text = parts[1].strip()
                for block in recs_text.split("---"):
                    block = block.strip()
                    if not block:
                        continue
                    name, reason, emoji = "", "", "🍽️"
                    for line in block.split('\n'):
                        line = line.strip()
                        if line.lower().startswith("name:"):
                            name = line[5:].strip()
                        elif line.lower().startswith("reason:"):
                            reason = line[7:].strip()
                        elif line.lower().startswith("emoji:"):
                            emoji = line[6:].strip()
                    if name and reason:
                        recommendations.append({"name": name, "reason": reason, "emoji": emoji})

            if not recommendations:
                recommendations = self._generate_recommendations(history, goals)

            return {
                "reply": main_reply,
                "recommendations": recommendations[:2],
                "recipes": [],
                "logged_foods": logged_foods,
            }

        except Exception as e:
            return {
                "reply": f"Sorry, I encountered an error: {str(e)}",
                "recommendations": [],
                "recipes": [],
                "logged_foods": [],
            }

    def _generate_recommendations(self, history, goals):
        current_cal = sum(item.get('calories', 0) for item in history)
        current_prot = sum(item.get('protein', 0) for item in history)
        target_cal = goals.get('daily_calories', 2000)
        target_prot = goals.get('protein_target', 50)

        if current_prot < target_prot and current_cal > (target_cal * 0.8):
            return [
                {"name": "Paneer Tikka (Grill)", "reason": "Lean protein with minimal fat", "emoji": "🥘"},
                {"name": "Soya Chunks Stir-fry", "reason": "Plant-based protein powerhouse", "emoji": "🥗"},
            ]
        elif current_cal >= target_cal:
            return [
                {"name": "Kachumber Salad", "reason": "Refreshing and extremely low calorie", "emoji": "🥗"},
                {"name": "Buttermilk (Chaas)", "reason": "Hydrating probiotic-rich drink", "emoji": "🥛"},
            ]
        else:
            return [
                {"name": "Moong Dal Khichdi", "reason": "Balanced macros, easy to digest", "emoji": "🥣"},
                {"name": "Grilled Chicken Wrap", "reason": "High protein, filling meal", "emoji": "🌯"},
            ]


# Singleton
chat_service = ChatService()


def get_chat_response(message, profile, history, goals):
    return chat_service.get_response(message, profile, history, goals)
