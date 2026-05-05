import { createAdminToken, validateCredentials } from "./_admin-session.js";

export default async function handler(request, response) {
  if (request.method !== "POST") {
    return response.status(405).json({ error: "Method not allowed." });
  }

  const { username, password } = request.body || {};
  if (!validateCredentials(username, password)) {
    return response.status(401).json({ error: "Invalid admin credentials." });
  }

  return response.status(200).json({ token: createAdminToken() });
}
