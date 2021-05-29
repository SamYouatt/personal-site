import express from 'express';
import ejs from 'ejs-mate';
import path from 'path';

class ExpressError extends Error {
    public message: string;
    public statusCode: number;

    constructor(message: string, statusCode: number) {
        super();
        this.message = message;
        this.statusCode = statusCode;
    }
}

const app = express();
const PORT = 8080;

app.engine('ejs', ejs);
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

app.use(express.static(path.join(__dirname, 'public')));

app.get('/', (req, res) => res.render('home'));

app.get('/about', (req, res) => res.render('about'));

app.get('/projects', (req, res) => res.render('projects'));

app.get('/contact', (req, res) => res.render('contact'));

app.all('*', (req, res, next) => {
    next(new ExpressError('Page not found', 404))
})

app.listen(PORT, () => {
    console.log(`⚡️[server]: Server started on http://localhost:${PORT}`)
})