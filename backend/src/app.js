import express from "express";
import cors from "cors";
import morgan from "morgan";

// Set's our port to the PORT environment variable, or 3000 by default if the env is not configured.
const PORT = process.env.PORT ?? 8080;

// Creates the express server
const app = express();

// Configure middleware (logging, CORS support, JSON parsing support, static files support)
app.use(morgan("combined"));
app.use(cors());
app.use(express.json());

// Import and use our application routes.
import routes from "./routes.js";
app.use(`/${process.env.API_STAGE_NAME || ''}`, routes);

app.use((err, req, res, next) => {
    console.log(err);
    return res.status(err.statusCode || 500).json();
});

app.listen(PORT, () => console.log(`App server listening on port ${PORT}!`));
