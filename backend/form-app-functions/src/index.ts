/**
 * Welcome to Cloudflare Workers! This is your first worker.
 *
 * - Run `npm run dev` in your terminal to start a development server
 * - Open a browser tab at http://localhost:8787/ to see your worker in action
 * - Run `npm run deploy` to publish your worker
 *
 * Bind resources to your worker in `wrangler.jsonc`. After adding bindings, a type definition for the
 * `Env` object can be regenerated with `npm run cf-typegen`.
 *
 * Learn more at https://developers.cloudflare.com/workers/
 */

interface Env {
  FIREBASE_PROJECT_ID: string;
  FIREBASE_CLIENT_EMAIL: string;
  FIREBASE_PRIVATE_KEY: string;
  SLACK_WEBHOOK_URL?: string;
  DISCORD_WEBHOOK_URL?: string;
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS, GET',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

export default {
  // Cron トリガー用 (毎日実行)
  async scheduled(event, env, ctx): Promise<void> {
    try {
      await checkSurveyNotify(env);
    } catch (error) {
      console.error('Scheduled notification error:', error);
    }
  },

  async fetch(request, env, ctx): Promise<Response> {
    const url = new URL(request.url);
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: corsHeaders });

    // アンケート通知の手動トリガー (テスト用)
    if (url.pathname === '/check-survey' && request.method === 'GET') {
      try {
        await checkSurveyNotify(env);
        return new Response(JSON.stringify({ success: true, message: 'Survey check completed' }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      } catch (error: any) {
        return new Response(JSON.stringify({ success: false, error: error.message }), {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
    }
    return new Response('Survey Notification Worker is running.');
  },
} satisfies ExportedHandler<Env>;

async function checkSurveyNotify(env: Env): Promise<void> {
  const token = await getFirebaseAccessToken(env);
  const now = new Date();
  const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);

  const firestoreBaseUrl = `https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents`;

  const queryResponse = await fetch(`${firestoreBaseUrl}:runQuery`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: 'survey_responses' }],
        where: {
          fieldFilter: {
            field: { fieldPath: 'submittedAt' },
            op: 'GREATER_THAN',
            value: { timestampValue: yesterday.toISOString() },
          },
        },
      },
    }),
  });

  const results: any = await queryResponse.json();
  if (!results || results.length === 0) return;

  for (const result of results) {
    if (!result.document) continue;

    const resDoc = result.document;
    const surveyId = resDoc.fields?.surveyId?.stringValue;
    const answers = resDoc.fields?.answers?.mapValue?.fields;
    const submittedAt = resDoc.fields?.submittedAt?.timestampValue;

    if (!surveyId || !answers) continue;

    const surveyRef = await fetch(`${firestoreBaseUrl}/surveys/${surveyId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    const surveyData: any = await surveyRef.json();
    const surveyTitle = surveyData.fields?.title?.stringValue || '無題のアンケート';

    const questionMap: Record<string, string> = {};
    const questions = surveyData.fields?.questions?.arrayValue?.values || [];
    questions.forEach((q: any) => {
      const qFields = q.mapValue.fields;
      questionMap[qFields.id.stringValue] = qFields.text.stringValue;
    });

    if (env.SLACK_WEBHOOK_URL) {
      await sendSlackNotification(env.SLACK_WEBHOOK_URL, surveyTitle, answers, submittedAt, questionMap);
    }
    if (env.DISCORD_WEBHOOK_URL) {
      await sendDiscordNotification(env.DISCORD_WEBHOOK_URL, surveyTitle, answers, submittedAt, questionMap);
    }
  }
}

async function sendSlackNotification(url: string, title: string, answers: any, time: string, qMap: Record<string, string>) {
  const answerText = formatAnswers(answers, qMap);
  const dateStr = new Date(time).toLocaleString('ja-JP', { timeZone: 'Asia/Tokyo' });

  const blocks = [
    { type: 'header', text: { type: 'plain_text', text: `✅ 新着回答: ${title}` } },
    { type: 'section', text: { type: 'mrkdwn', text: `*提出時刻 (JST):* ${dateStr}\n\n${answerText}` } },
  ];

  await fetch(url, { method: 'POST', body: JSON.stringify({ blocks }) });
}

async function sendDiscordNotification(url: string, title: string, answers: any, time: string, qMap: Record<string, string>) {
  const fields = Object.entries(answers).map(([key, val]: [string, any]) => ({
    name: qMap[key] || key,
    value: val.stringValue || val.integerValue || val.booleanValue?.toString() || '-',
    inline: false,
  }));

  await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      embeds: [
        {
          title: `✅ 新着回答: ${title}`,
          color: 5814783,
          fields: fields,
          timestamp: new Date(time).toISOString(),
        },
      ],
    }),
  });
}

function formatAnswers(answers: any, qMap: Record<string, string>): string {
  return Object.entries(answers)
    .map(([key, value]: [string, any]) => {
      const qText = qMap[key] || `ID: ${key}`;
      const aText = value.stringValue || value.integerValue || value.booleanValue?.toString() || '-';
      return `• *${qText}:*\n  ${aText}`;
    })
    .join('\n');
}

async function getFirebaseAccessToken(env: Env): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const claim = {
    iss: env.FIREBASE_CLIENT_EMAIL,
    scope: 'https://www.googleapis.com/auth/datastore',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now,
  };
  const token = await signJWT({ alg: 'RS256', typ: 'JWT' }, claim, env.FIREBASE_PRIVATE_KEY);
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: token }),
  });
  const data: any = await res.json();
  return data.access_token;
}

async function signJWT(header: any, payload: any, privateKey: string): Promise<string> {
  const encoder = new TextEncoder();
  const hB64 = btoa(JSON.stringify(header)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  const pB64 = btoa(JSON.stringify(payload)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  const data = `${hB64}.${pB64}`;
  const key = await crypto.subtle.importKey('pkcs8', pemToArrayBuffer(privateKey), { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, [
    'sign',
  ]);
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, encoder.encode(data));
  const sB64 = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
  return `${data}.${sB64}`;
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem.replace(/\\n/g, '\n').split('-----')[2].replace(/\s/g, '');
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}
