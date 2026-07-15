require('dotenv').config();
const express = require('express');
const cors    = require('cors');
const path    = require('path');
const fs      = require('fs');
const fetch   = require('node-fetch');

const app  = express();
const PORT = process.env.PORT || 3000;

const GEMINI_API_KEY = process.env.GEMINI_API_KEY ? process.env.GEMINI_API_KEY.trim() : '';
const GEMINI_MODEL   = 'gemini-3.5-flash';
const GEMINI_URL     = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`;

if (!GEMINI_API_KEY) {
  console.warn('⚠️  GEMINI_API_KEY not found or empty in .env – falling back to FAQ mode.');
}

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

let chatHistory = [];

// ─── FAQ Knowledge Base (fallback) ────────────────────────────────────────────
const faqPath = path.join(__dirname, 'faq.json');
let faqEntries = [];
try {
  faqEntries = JSON.parse(fs.readFileSync(faqPath, 'utf8'));
} catch (error) {
  console.error('Failed to load faq.json:', error);
}

function escapeRegExp(string) {
  return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function getFaqResponse(userInput) {
  const inputLower = userInput.toLowerCase();
  for (const entry of faqEntries) {
    for (const kw of entry.keywords) {
      const escapedKw = escapeRegExp(kw);
      const regex = new RegExp(`(^|\\s|[^a-z])${escapedKw}([^a-z]|\\s|$)`, 'i');
      if (regex.test(inputLower)) {
        return entry.answer;
      }
    }
  }
  return null;
}

// ─── Gemini API Call ──────────────────────────────────────────────────────────
async function getGeminiResponse(userMessage, history) {
  // Build conversation history for context (last 10 turns)
  const recentHistory = history.slice(-20);
  const contents = recentHistory.map(msg => ({
    role: msg.sender === 'user' ? 'user' : 'model',
    parts: [{ text: msg.text }]
  }));

  // Add current user message
  contents.push({
    role: 'user',
    parts: [{ text: userMessage }]
  });

  const body = {
    system_instruction: {
      parts: [{
        text: `You are Zaid Chatbot, a friendly and knowledgeable AI assistant. 
You help users with programming, web development, tech concepts, writing, and creative brainstorming. 
Be concise but thorough. Use markdown formatting when helpful (code blocks, bullet points). 
Keep responses friendly and engaging. If asked about your identity, say you are Zaid Chatbot, an AI assistant.`
      }]
    },
    contents,
    generationConfig: {
      temperature: 0.9,
      topP: 0.95,
      topK: 64,
      maxOutputTokens: 2048,
    }
  };

  const response = await fetch(GEMINI_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Gemini API error ${response.status}: ${errText}`);
  }

  const data = await response.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error('Empty response from Gemini API');
  return text;
}

// ─── Routes ───────────────────────────────────────────────────────────────────
app.get('/api/status', (req, res) => {
  res.json({
    status: 'online',
    aiEnabled: !!GEMINI_API_KEY,
    model: GEMINI_API_KEY ? GEMINI_MODEL : 'FAQ Mode (Local)'
  });
});

app.get('/api/history', (req, res) => res.json(chatHistory));

app.post('/api/chat', async (req, res) => {
  const { message } = req.body;
  if (!message) return res.status(400).json({ error: 'Message is required.' });

  const timestamp = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

  // Record user message
  chatHistory.push({ sender: 'user', text: message, timestamp });

  let botText;

  if (GEMINI_API_KEY) {
    try {
      // Use Gemini AI (pass history excluding the last user message we just pushed)
      botText = await getGeminiResponse(message, chatHistory.slice(0, -1));
    } catch (err) {
      console.error('Gemini API failed, falling back to FAQ:', err.message);
      // Fallback to FAQ
      botText = getFaqResponse(message) ||
        `I'm having trouble connecting to AI right now. 🤔\n\nTry asking about:\n- Programming (JavaScript, Python, Node.js)\n- Web development (HTML, CSS, databases)\n- Tech concepts (AI/ML, Docker, Git)\n\nType **'help'** to see all topics.`;
    }
  } else {
    // No API key — use FAQ matching
    botText = getFaqResponse(message) ||
      `I'm not sure I have a specific answer for that yet! 🤔\n\nTry asking about:\n- Programming (JavaScript, Python, Node.js, REST APIs)\n- Web development (HTML, CSS, databases)\n- Tech concepts (AI/ML, Docker, Git, security)\n\nType **'help'** to see all available topics.`;
  }

  const botMsg = { sender: 'bot', text: botText, timestamp };
  chatHistory.push(botMsg);

  res.json(botMsg);
});

app.delete('/api/history', (req, res) => {
  chatHistory = [];
  res.json({ message: 'Chat history cleared.' });
});

app.listen(PORT, () => {
  console.log(`✨ Zaid Chatbot server running on http://localhost:${PORT}`);
  console.log(`🤖 AI Backend: ${GEMINI_API_KEY ? `Gemini (${GEMINI_MODEL})` : 'FAQ Fallback Mode'}`);
});
