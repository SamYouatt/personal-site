import express from 'express';

const app = express();
const PORT = 8080;

app.get('/', (req, res) => res.send('Test'));

app.listen(PORT, () => {
    console.log(`⚡️[server]: Server started on http://localhost:${PORT}`)
})