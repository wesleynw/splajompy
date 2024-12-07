import type { Metadata } from "next";
import "./globals.css";
import { AppRouterCacheProvider } from "@mui/material-nextjs/v14-appRouter";
import { Roboto } from "next/font/google";
import { ThemeProvider } from "@mui/material/styles";
import theme from "../theme";
import { SpeedInsights } from "@vercel/speed-insights/next";
import { Box } from "@mui/material";
import InitColorSchemeScript from "@mui/material/InitColorSchemeScript";
import TopBar from "./components/navigation/TopBar";
import { FeedProvider } from "./data/FeedProvider";
import PlausibleProvider from "next-plausible";

const roboto = Roboto({
  weight: ["300", "400", "500", "700"],
  subsets: ["latin"],
  display: "swap",
  variable: "--font-roboto",
});

export const metadata: Metadata = {
  title: "Splajompy",
  description: "One of the websites of all time.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <PlausibleProvider
          domain="splajompy.com"
          customDomain="https://analytics.splajompy.com"
          selfHosted
        />
      </head>
      <body className={roboto.variable}>
        <AppRouterCacheProvider>
          <ThemeProvider theme={theme}>
            <TopBar />
            <InitColorSchemeScript attribute="class" />
            <Box component="main" sx={{ paddingTop: "60px" }}>
              <FeedProvider>{children}</FeedProvider>
            </Box>

            <SpeedInsights />
          </ThemeProvider>
        </AppRouterCacheProvider>
      </body>
    </html>
  );
}
