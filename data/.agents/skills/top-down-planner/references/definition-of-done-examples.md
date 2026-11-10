# Definition of Done — Good vs. Bad Examples

The Definition of Done (DoD) tells the learner exactly when they can move forward.
A bad DoD creates false confidence. A good DoD is specific, observable, and executable.

---

## ❌ Bad Definitions of Done

These are vague and unactionable:

- "You understand variables"
- "You are comfortable with loops"
- "You have a basic understanding of APIs"
- "You know how to use Git"

**Why they fail:** The learner can tick these boxes without actually knowing anything,
because they're not tied to any observable action.

---

## ✅ Good Definitions of Done

### Example 1 — Variables & Data Types (Python, beginner)

```
✅ Definition of Done: Variables & Data Types

- [ ] Without looking anything up, you can declare a variable of each basic type
      (str, int, float, bool, list, dict) and print its type using type()
- [ ] You can explain in one sentence why Python is dynamically typed,
      using a real code example you wrote yourself
- [ ] Running this code without errors:
      name = "Ada"
      age = 36
      print(f"{name} will be {age + 1} next year")
      → Output: "Ada will be 37 next year"
```

---

### Example 2 — Git Basics (beginner)

```
✅ Definition of Done: Git Basics

- [ ] You can initialize a repo, make a commit, and push to GitHub
      entirely from the terminal — without looking at your notes
- [ ] You can explain the difference between `git add`, `git commit`, and `git push`
      to someone who has never used Git
- [ ] Starting from a fresh folder, you can run:
        git init
        git add .
        git commit -m "first commit"
        git remote add origin [url]
        git push -u origin main
      and see your files appear on GitHub
```

---

### Example 3 — REST API Consumption (beginner/intermediate)

```
✅ Definition of Done: Consuming a REST API

- [ ] You can make a GET request to a public API (e.g., https://api.github.com/users/[username])
      and print a specific field from the JSON response — without a tutorial open
- [ ] You can explain what a status code 200, 404, and 500 mean and when each occurs
- [ ] You write a function fetch_user(username) that returns the user's public repo count
      from the GitHub API. The function handles the case where the user doesn't exist (404).
```

---

### Example 4 — Database CRUD (intermediate)

```
✅ Definition of Done: Basic CRUD with SQLite

- [ ] You can create a table, insert a record, query all records, update one record,
      and delete one record — using raw SQL in Python's sqlite3 module — without notes
- [ ] You can explain the difference between DELETE and DROP TABLE
- [ ] You build a small CLI tool that manages a "to-do" list stored in a .db file.
      It must support: add [task], list, done [id], delete [id]
```

---

## Pattern: The Three-Axis Check

Every good Definition of Done tests on three axes:

| Axis | Question it answers | Example verb |
|------|---------------------|--------------|
| **Understanding** | Can you explain it? | "Explain to someone else..." |
| **Ability** | Can you do it unaided? | "Without looking at notes..." |
| **Output** | Can you produce a working artifact? | "Running X produces Y..." |

When writing a DoD, make sure at least one check covers each axis.
