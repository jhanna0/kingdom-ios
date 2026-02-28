"""
Server Prompts Router - Backend-driven popups (feedback, polls, announcements)

The frontend is dumb - it just loads whatever URL we give it in a WebView.
All content/logic is controlled by the backend via modal_url.
"""

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel
from typing import Optional
from datetime import datetime

from db import get_db
from routers.auth import get_current_user

router = APIRouter(prefix="/prompts", tags=["prompts"])


class PromptResponse(BaseModel):
    id: str
    modal_url: str


class CheckResponse(BaseModel):
    success: bool
    prompt: Optional[PromptResponse] = None


class DismissRequest(BaseModel):
    prompt_id: str


@router.get("/check", response_model=CheckResponse)
def check_prompt(
    platform: str = "ios",
    user=Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Check if there's an active prompt to show the user.
    Returns the most recent non-expired prompt that:
    - User hasn't dismissed 3+ times, OR
    - Was last shown 2+ days ago (if dismissed < 3 times)
    """
    result = db.execute(text("""
        SELECT p.id, p.modal_url
        FROM server_prompts p
        LEFT JOIN prompt_dismissals d ON d.prompt_id = p.id AND d.user_id = :user_id
        WHERE (p.expires_at IS NULL OR p.expires_at > NOW())
          AND (p.target_platform = :platform OR p.target_platform = 'all')
          AND (
              d.id IS NULL
              OR (d.completed = FALSE AND d.dismissal_count < 3 AND d.last_shown_at < NOW() - INTERVAL '12 hour') // should be 12 hour
          )
        ORDER BY p.created_at DESC
        LIMIT 1
    """), {"platform": platform, "user_id": user.id})
    
    row = result.fetchone()
    
    if not row:
        return {"success": True, "prompt": None}
    
    prompt_id = str(row.id)
    modal_url = row.modal_url
    
    # Append prompt_id as query param if not already present
    if "?" in modal_url:
        modal_url = f"{modal_url}&prompt_id={prompt_id}"
    else:
        modal_url = f"{modal_url}?prompt_id={prompt_id}"
    
    return {
        "success": True,
        "prompt": {
            "id": prompt_id,
            "modal_url": modal_url
        }
    }


@router.post("/dismiss")
def dismiss_prompt(
    request: DismissRequest,
    user=Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Record that user dismissed a prompt.
    Increments dismissal count and updates last_shown_at.
    After 3 dismissals, prompt won't show again.
    """
    if not request.prompt_id:
        raise HTTPException(status_code=400, detail="Missing prompt_id")
    
    db.execute(text("""
        INSERT INTO prompt_dismissals (user_id, prompt_id, dismissal_count, last_shown_at, dismissed_at)
        VALUES (:user_id, :prompt_id, 1, NOW(), NOW())
        ON CONFLICT (user_id, prompt_id) DO UPDATE SET
            dismissal_count = prompt_dismissals.dismissal_count + 1,
            last_shown_at = NOW(),
            dismissed_at = NOW()
    """), {"user_id": user.id, "prompt_id": request.prompt_id})
    db.commit()
    
    return {"success": True}


# ============================================================
# HTML Form Endpoints - Served in WebView
# ============================================================

from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
security = HTTPBearer()


@router.get("/feedback-form", response_class=HTMLResponse)
def feedback_form(
    prompt_id: Optional[str] = None,
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """
    Serves HTML feedback form. Token comes from Authorization header.
    Form submits to /feedback endpoint with JWT auth.
    """
    token = credentials.credentials
    return f"""
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>Feedback</title>
    <style>
        * {{
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #F2DEB3;
            min-height: 100vh;
            padding: 24px;
        }}
        .container {{
            max-width: 400px;
            margin: 0 auto;
        }}
        .icon {{
            width: 80px;
            height: 80px;
            background: #4A7C59;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 20px;
            border: 3px solid #000;
            box-shadow: 3px 3px 0 #000;
        }}
        .icon svg {{
            width: 40px;
            height: 40px;
            fill: white;
        }}
        h1 {{
            font-size: 24px;
            font-weight: 800;
            text-align: center;
            margin-bottom: 8px;
            color: #1a1a1a;
        }}
        .subtitle {{
            text-align: center;
            color: #555;
            margin-bottom: 24px;
            font-size: 15px;
        }}
        textarea {{
            width: 100%;
            height: 150px;
            padding: 16px;
            border: 3px solid #000;
            border-radius: 12px;
            font-size: 16px;
            font-family: inherit;
            resize: none;
            background: #fff;
            box-shadow: 3px 3px 0 #000;
        }}
        textarea:focus {{
            outline: none;
            border-color: #4A7C59;
        }}
        .char-count {{
            text-align: right;
            font-size: 12px;
            color: #888;
            margin-top: 8px;
        }}
        button {{
            width: 100%;
            padding: 16px;
            margin-top: 20px;
            background: #5C4033;
            color: white;
            border: 3px solid #000;
            border-radius: 12px;
            font-size: 16px;
            font-weight: 700;
            cursor: pointer;
            box-shadow: 3px 3px 0 #000;
            transition: transform 0.1s, box-shadow 0.1s;
        }}
        button:active {{
            transform: translate(2px, 2px);
            box-shadow: 1px 1px 0 #000;
        }}
        button:disabled {{
            background: #999;
            cursor: not-allowed;
        }}
        .success {{
            text-align: center;
            padding: 40px 20px;
        }}
        .success h2 {{
            color: #4A7C59;
            margin-bottom: 12px;
        }}
        .error {{
            background: #ffebee;
            color: #c62828;
            padding: 12px;
            border-radius: 8px;
            margin-top: 16px;
            display: none;
        }}
        .hidden {{
            display: none;
        }}
    </style>
</head>
<body>
    <div class="container">
        <div id="form-view">
            <div class="icon">
                <svg viewBox="0 0 24 24"><path d="M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm0 14H6l-2 2V4h16v12z"/></svg>
            </div>
            <h1>Share Your Feedback</h1>
            <p class="subtitle">Help us improve Kingdom! What features would you like to see?</p>
            
            <textarea id="message" placeholder="Your ideas, suggestions, or feedback..." maxlength="1000"></textarea>
            <div class="char-count"><span id="count">0</span>/1000</div>
            
            <div id="error" class="error"></div>
            
            <button id="submit" onclick="submitFeedback()">Send Feedback</button>
        </div>
        
        <div id="success-view" class="success hidden">
            <div class="icon">
                <svg viewBox="0 0 24 24"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg>
            </div>
            <h2>Thank You!</h2>
            <p class="subtitle">Your feedback has been received. We really appreciate you taking the time to help us improve.</p>
        </div>
    </div>
    
    <script>
        const token = "{token}";
        const promptId = "{prompt_id}";
        
        const textarea = document.getElementById('message');
        const countEl = document.getElementById('count');
        
        textarea.addEventListener('input', function() {{
            countEl.textContent = this.value.length;
        }});
        
        async function submitFeedback() {{
            const message = textarea.value.trim();
            const errorEl = document.getElementById('error');
            const submitBtn = document.getElementById('submit');
            
            if (message.length < 5) {{
                errorEl.textContent = 'Please write at least 5 characters.';
                errorEl.style.display = 'block';
                return;
            }}
            
            errorEl.style.display = 'none';
            submitBtn.disabled = true;
            submitBtn.textContent = 'Sending...';
            
            try {{
                const response = await fetch('/feedback', {{
                    method: 'POST',
                    headers: {{
                        'Content-Type': 'application/json',
                        'Authorization': 'Bearer ' + token
                    }},
                    body: JSON.stringify({{ message: message, prompt_id: promptId || null }})
                }});
                
                if (!response.ok) {{
                    throw new Error('Failed to submit');
                }}
                
                document.getElementById('form-view').classList.add('hidden');
                document.getElementById('success-view').classList.remove('hidden');
                
            }} catch (e) {{
                errorEl.textContent = 'Something went wrong. Please try again.';
                errorEl.style.display = 'block';
                submitBtn.disabled = false;
                submitBtn.textContent = 'Send Feedback';
            }}
        }}
    </script>
</body>
</html>
"""
