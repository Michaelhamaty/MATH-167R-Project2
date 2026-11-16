# Prompt history

This is the record of how I directed the agent on this project. Each entry has the date, my prompt, and what I decided or told the agent to do next.

Where the entry has quotation marks, those are my exact words, typos included. Where it does not, the wording was not saved, so I describe what I asked. The agent wrote code and first drafts. I chose the category set, the chain rule, the word list, the neighborhood rule, and the reviewer baseline.

## 1. 2026-11-02: set up the project

**Prompt (described):** I told the agent to stay in the Project2 folder, download and unzip the Yelp files, filter them to New Orleans, and save the result as RDS files. If the disk got tight, it could delete the raw files. Then push to https://github.com/Michaelhamaty/MATH-167R-Project2.git. I asked for code that is not overly complex and has comments.

**Decision:** The import runs in chunks because my laptop has 8 GB of RAM. Raw JSON stays out of the repo.

## 2. 2026-11-10: ask for explanations and creative options

**Prompt:** "take a look at what the project contains. see what exists. today we will be working on working up to section 6, so I want you to offer me explinations about what it is asking for, and to give me creative options, I am trying to say food for my creativity to design it."

**Decision:** From the options I chose a foodie rule: local, creative, and worth staying for.

## 3. 2026-11-10: pick a model page

**Prompt (described):** I pointed at https://michaelhamaty.github.io/Math-167R-Assignment-4-Submission/ and said this project should look like that page. I asked which parts of it could carry over.

**Decision:** One scroll, a paragraph and then a table or figure, code folded under "View R code".

## 4. 2026-11-10: have the agent ask me questions

**Prompt:** "ask me questions to get me there. The questions where I get to add my touch. It is important to keep all R code human readable and more to the simple side."

**Decision:** I locked four categories (American (new), cocktail bars, cafes, seafood), the chain rule at more than two locations, the seven-word list with a 5% cutoff, neighborhoods as the main geography, tracts as the comparison, and a stars ranking that needs at least 5 places. Leonidas came out first.

## 5. 2026-11-10: finish through Step 6

**Prompt (described):** I told the agent to finish through Step 6 only, review the code, add graphs and tables, and keep the R simple and lightly commented. I told it to pass the locked choices to a fresh agent and to stop asking me questions.

**Decision:** I stopped the work before reviewer-adjusted scores.

## 6. 2026-11-10: make the page look right

**Prompt (described):** I asked for the page to look like the GitHub Pages link from entry 3, neat, and with the graphs showing. Then I asked for a clickable link on the README.

**Decision:** The report is one self-contained HTML file, linked from the top of the README.

## 7. 2026-11-15: check status

**Prompt (described):** I asked for a numbered status of what was done and what was left, the grading requirements, whether extra credit existed, and a short answer.

**Decision:** There is no extra credit. Step 7, the top 10, and this prompt log were the three required pieces left.

## 8. 2026-11-15: carry my choices into the rest

**Prompt (described):** I asked for questions so the rest of the project would carry my choices. I kept first person, the current scroll, and the code dropdown, and asked for a short comment in the R on what it is doing. I asked for a prompt log that shows I drove the agent: the creative options, the questions that added my touch, and the prompts where I assigned the work.

**Decision:** First person only where I made the decision. Short comments in the code.

## 9. 2026-11-15: set the remaining rules

**Prompt (described):** I set the rules for the rest: two lists with a plain definition of each column, no raw-review floor beyond 5 reviews from eligible reviewers, both neighborhood results shown with their rules, and the median baseline framed as my choice. I told the agent to write the handoff.

**Decision:** The median is each reviewer's usual score. A place needs 5 eligible-reviewer reviews to be scored. Leonidas stays in the stars ranking.

## 10. 2026-11-15: add my own touch before the finish

**Prompt:** "For this handoff prompt, the whole idea is for me to add my own creative touch to it. So I want you to ask me some questions about it."

**Decision:** The agent asked four questions, and I answered each one. The number is called the "adjusted score". The scatter names only the adjusted top 10. The map uses numbered copper dots. This session is entry 10 in the log. I also asked for work to be saved as it went and for the final repository to be clean and easy for my professor to read.
