import os
from dotenv import load_dotenv
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel
from chatbot import chatbot

app = FastAPI()

load_dotenv()

API_KEY = os.getenv("API_KEY")


class ChatRequest(BaseModel):
    message: str
    history: list = []


@app.post("/chat")
def chat(request: ChatRequest, x_api_key: str = Header(None)):

    if x_api_key != API_KEY:
        raise HTTPException(
            status_code=401,
            detail="Invalid API key"
        )

    return {
        "reply": chatbot(
            request.message,
            request.history
        )
    }