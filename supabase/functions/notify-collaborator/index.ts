import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  try {
    const { email, chartTitle, ownerEmail, role, appUrl } = await req.json()
    if (!email || !chartTitle || !ownerEmail) {
      return new Response(JSON.stringify({ error: 'Missing required fields' }), {
        status: 400, headers: { ...CORS, 'Content-Type': 'application/json' },
      })
    }

    const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')
    if (!RESEND_API_KEY) {
      // Not configured — return 200 so the frontend doesn't treat it as a hard error
      return new Response(JSON.stringify({ skipped: true, reason: 'RESEND_API_KEY not set' }), {
        status: 200, headers: { ...CORS, 'Content-Type': 'application/json' },
      })
    }

    const FROM_EMAIL = Deno.env.get('NOTIFY_FROM_EMAIL') || 'Gantt Planner <noreply@resend.dev>'
    const roleLabel = role === 'editor' ? 'editor (can edit blocks)' : 'viewer (read-only)'

    const html = `
      <div style="font-family:sans-serif;max-width:480px;margin:0 auto;color:#2f3743">
        <h2 style="font-size:20px;margin-bottom:8px">You've been added as a collaborator</h2>
        <p><strong>${ownerEmail}</strong> has shared a Gantt chart with you:</p>
        <div style="background:#f4f5f7;border-radius:10px;padding:14px 18px;margin:16px 0">
          <div style="font-size:16px;font-weight:600">${chartTitle}</div>
          <div style="font-size:13px;color:#6b7280;margin-top:4px">Your access: ${roleLabel}</div>
        </div>
        <a href="${appUrl}" style="display:inline-block;background:#2563eb;color:#fff;padding:10px 20px;border-radius:8px;text-decoration:none;font-weight:600">Open Gantt Planner</a>
        <p style="margin-top:20px;font-size:12px;color:#9ca3af">
          Sign in using <strong>${email}</strong> to access this chart.<br>
          This notification was sent because someone shared a Cloud Gantt chart with you.
        </p>
      </div>
    `

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${RESEND_API_KEY}` },
      body: JSON.stringify({
        from: FROM_EMAIL,
        to: [email],
        subject: `${ownerEmail} shared "${chartTitle}" with you`,
        html,
      }),
    })

    const data = await res.json()
    if (!res.ok) throw new Error(data.message || `Resend error ${res.status}`)

    return new Response(JSON.stringify({ sent: true, id: data.id }), {
      headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('notify-collaborator error:', err)
    return new Response(JSON.stringify({ error: String(err.message || err) }), {
      status: 500, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }
})
