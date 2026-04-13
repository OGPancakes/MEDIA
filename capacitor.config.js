const serverUrl = process.env.CAP_SERVER_URL || "http://127.0.0.1:5000";

module.exports = {
  appId: "com.piasocial.app",
  appName: "PIA Social",
  webDir: "app/static",
  server: {
    url: serverUrl,
    cleartext: serverUrl.startsWith("http://")
  },
  ios: {
    contentInset: "automatic"
  }
};
