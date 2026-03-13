import os
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

    def get_response(self, 
                     message: str, 
                     profile: Dict[str, Any], 
                     history: List[Dict[str, Any]], 
                     goals: Dict[str, Any]) -> Dict[str, Any]:
        """
        Generates a dietitian response based on user message and context.
        """
        if not self.client:
            return {
                "reply": "I'm currently in offline mode. Please configure an OpenAI API key to start chatting!",
                "recommendations": []
            }

        # Format context for the AI
        user_context = f"User Profile: {profile.get('name', 'User')}, Rank: {profile.get('rank', 'Novice')}.\n"
        user_context += f"Goals: {goals.get('daily_calories', 2000)} kcal, {goals.get('protein_target', 50)}g protein.\n"
        
        # Calculate current daily intake from history (simplified for prompt)
        current_cal = sum(item.get('calories', 0) for item in history)
        current_prot = sum(item.get('protein', 0) for item in history)
        
        user_context += f"Today's Intake so far: {current_cal} kcal, {current_prot}g protein.\n"

        system_prompt = (
            "You are 'AI Dietitian', a professional, friendly, and highly knowledgeable Indian nutrition expert. "
            "Your goal is to help the user meet their health goals without needing a human dietitian. "
            "Use the provided context to give personalized advice based on their Indian diet (Biryani, Dosa, Paneer, etc.). "
            "FORMATTING RULES:\n"
            "1. NEVER use markdown tables. They are hard to read on mobile.\n"
            "2. ALWAYS use hyphens (-) for bullet points with a space after specifically for markdown lists.\n"
            "3. Use bold text (**) for categories and food names.\n"
            "4. Use emojis appropriately to make it engaging.\n"
            "5. Be concise, encouraging, and medically grounded.\n"
            "6. Structure responses like Gemini or ChatGPT: clear headings, spacing, and short paragraphs.\n"
            "7. IMPORTANT: Do NOT include your own name or headers like 'Antigravity AI' in the response. Just provide the message content directly."
        )

        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "assistant", "content": f"Context: {user_context}"},
                    {"role": "user", "content": message}
                ],
                temperature=0.7
            )
            
            reply = response.choices[0].message.content
            
            # Extract simple recommendations if any (heuristic or can be part of prompt)
            recommendations = self._generate_recommendations(history, goals)
            
            return {
                "reply": reply,
                "recommendations": recommendations
            }
        except Exception as e:
            return {
                "reply": f"Sorry, I encountered an error: {str(e)}",
                "recommendations": []
            }

    def _generate_recommendations(self, history: List[Dict[str, Any]], goals: Dict[str, Any]) -> List[Dict[str, Any]]:
        """
        Simple logic to suggest foods based on macro gaps.
        """
        current_cal = sum(item.get('calories', 0) for item in history)
        current_prot = sum(item.get('protein', 0) for item in history)
        
        target_cal = goals.get('daily_calories', 2000)
        target_prot = goals.get('protein_target', 50)
        
        recs = []
        
        # If low on protein but near calorie limit
        if current_prot < target_prot and current_cal > (target_cal * 0.8):
            recs.append({"name": "Paneer Tikka (Grill)", "reason": "Lean protein with minimal fat compared to butter gravy", "emoji": "🥘"})
            recs.append({"name": "Soya Chunks Stir-fry", "reason": "Plant-based protein powerhouse for your muscle recovery", "emoji": "🥗"})
        
        # If hungry but at calorie limit
        elif current_cal >= target_cal:
            recs.append({"name": "Kachumber Salad", "reason": "Refreshing Indian salad to keep you full without calories", "emoji": "🥗"})
            recs.append({"name": "Buttermilk (Chaas)", "reason": "Hydrating, probiotic-rich and extremely low calorie", "emoji": "🥛"})
            
        # General healthy Indian options for energy
        else:
            recs.append({"name": "Moong Dal Khichdi", "reason": "Light, easy to digest and perfectly balanced macros", "emoji": "🥣"})
            recs.append({"name": "Methi Thepla", "reason": "Fiber-rich regional flatbread for sustained energy", "emoji": "🫓"})

        return recs[:2] # Return top 2

# Singleton
chat_service = ChatService()

def get_chat_response(message, profile, history, goals):
    return chat_service.get_response(message, profile, history, goals)
