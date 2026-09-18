import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const internalEmailDomain = "@vagdmp.internal";
const validRoles = new Set(["leader", "supervisor", "admin"]);
const validUsername = /^[a-z0-9._-]{3,32}$/;

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const token = request.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "Sign in is required" }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    console.error("Missing Supabase function secrets");
    return json({ error: "Server configuration error" }, 500);
  }

  // The service-role client is deliberately kept inside this trusted function;
  // it must never be bundled in the Flutter application.
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: authData, error: authError } = await admin.auth.getUser(token);
  if (authError || !authData.user) return json({ error: "Invalid session" }, 401);

  const { data: caller, error: callerError } = await admin
    .from("profiles")
    .select("role, active")
    .eq("id", authData.user.id)
    .single();
  if (callerError || caller?.role !== "admin" || !caller.active) {
    return json({ error: "Administrator access is required" }, 403);
  }

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch (_) {
    return json({ error: "Invalid request body" }, 400);
  }

  const username = String(body.username ?? "").trim().toLowerCase();
  const password = String(body.password ?? "");
  const fullName = String(body.fullName ?? "").trim();
  const role = String(body.role ?? "").trim().toLowerCase();
  const villageId = String(body.villageId ?? "").trim();

  if (!validUsername.test(username)) {
    return json({ error: "Username must be 3–32 letters, numbers, dots, underscores, or hyphens" }, 400);
  }
  if (password.length < 12) return json({ error: "Password must be at least 12 characters" }, 400);
  if (!fullName || fullName.length > 120) return json({ error: "A valid full name is required" }, 400);
  if (!validRoles.has(role)) return json({ error: "Invalid role" }, 400);
  if (!villageId) return json({ error: "An assigned village is required" }, 400);

  const email = `${username}${internalEmailDomain}`;
  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { username, full_name: fullName },
  });
  if (createError || !created.user) {
    return json({ error: createError?.message ?? "Could not create account" }, 400);
  }

  // Upsert also supports projects that create an empty profile via an Auth
  // trigger. On failure, remove the newly-created Auth account to avoid an
  // account that cannot log in to the application.
  const { error: profileError } = await admin.from("profiles").upsert(
    {
      id: created.user.id,
      username,
      full_name: fullName,
      role,
      village_id: villageId,
      active: true,
    },
    { onConflict: "id" },
  );
  if (profileError) {
    console.error("Profile creation failed", profileError.message);
    await admin.auth.admin.deleteUser(created.user.id);
    return json({ error: "Could not create the user profile" }, 500);
  }

  return json({ id: created.user.id, username }, 201);
});

function json(body: Record<string, string>, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
