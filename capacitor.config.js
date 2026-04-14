const serverUrl = process.env.CAP_SERVER_URL || "https://media-production-0abd.up.railway.app";

module.exports = {
  appId: "com.piasocial.app",
  appName: "PIA Social",
  webDir: "app/static",
  backgroundColor: "#eef4ff",
  server: {
    url: serverUrl,
    cleartext: serverUrl.startsWith("http://")
  },
  ios: {
    contentInset: "never",
    backgroundColor: "#eef4ff",
    preferredContentMode: "mobile"
  }
};
