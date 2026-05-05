import { createAdminToken, response, validateCredentials } from "./_admin-session.js";

export const handler = async (event) => {
  if (event.httpMethod !== "POST") {
    return response(405, { error: "Method not allowed." });
  }

  const { username, password } = JSON.parse(event.body || "{}");
  if (!validateCredentials(username, password)) {
    return response(401, { error: "Invalid admin credentials." });
  }

  return response(200, { token: createAdminToken() });
};
