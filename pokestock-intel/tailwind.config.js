/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,jsx}"],
  theme: {
    extend: {
      fontFamily: {
        sans: ['"Inter"', '"SF Pro Display"', '"Avenir Next"', "system-ui", "sans-serif"],
      },
      boxShadow: {
        glass: "0 24px 80px rgba(0, 0, 0, 0.28)",
        lift: "0 16px 42px rgba(15, 23, 42, 0.28)",
      },
    },
  },
  plugins: [],
};
