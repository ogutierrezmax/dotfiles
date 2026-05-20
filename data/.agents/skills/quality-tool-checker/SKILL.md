---
name: quality-tool-checker
description: >
  Checks which code quality tools are installed in the current project.
  Use when the user asks about installed quality tools, wants to verify tool availability,
  or mentions SonarQube, code-quality-kit, or similar code analysis tools.
  Triggers on phrases like "what quality tools do I have", "is sonarqube installed",
  "check quality tools", "quality tool status", or any request to audit code quality tooling.
---

# Quality Tool Checker

This skill checks which code quality tools are currently installed and available in the project.

## Tools to Check

When this skill is invoked, check for the following tools:

### 1. SonarQube

**Detection methods:**
- Check for `sonar-project.properties` file in project root
- Check `package.json` for `sonarqube-scanner` or `sonar-scanner` dependencies
- Run `which sonar-scanner` or `npx sonar-scanner --version`
- Check for Docker Compose with SonarQube service (`docker-compose.yml` containing `sonarqube`)
- Check environment variables for `SONAR_HOST_URL` or `SONAR_TOKEN`

**Status reporting:**
- `Installed` - Found executable or dependency
- `Configured` - Found configuration file
- `Not installed` - Nothing found

### 2. code-quality-kit (npm)

**Detection methods:**
- Check `package.json` for `code-quality-kit` dependency
- Run `npm list code-quality-kit` or `npx code-quality-kit --version`
- Check `node_modules/code-quality-kit` directory exists

**Status reporting:**
- `Installed` - Found in node_modules or package.json
- `Not installed` - Nothing found

## How to Check

1. **Read project files:**
   - `package.json` - Look for dependencies/devDependencies
   - `sonar-project.properties` - SonarQube config
   - `docker-compose.yml` - Containerized tools
   - `.env` files - Environment configuration

2. **Run commands:**
   ```bash
   # Check global installations
   which sonar-scanner
   which sonarqube-scanner

   # Check npm packages
   npm list --depth=0 2>/dev/null | grep -E "sonar|code-quality"

   # Check npx availability
   npx --yes code-quality-kit --version 2>&1
   ```

3. **Check Docker:**
   ```bash
   docker ps --format '{{.Names}}' | grep -i sonar
   docker-compose config --services 2>/dev/null | grep -i sonar
   ```

## Output Format

Present results in a clear table:

```markdown
## Quality Tools Status

| Tool | Installed | Configured | Version |
|------|-----------|------------|---------|
| SonarQube | ✅/❌ | ✅/❌ | x.x.x or N/A |
| code-quality-kit | ✅/❌ | N/A | x.x.x or N/A |
```

## Adding New Tools

To add more tools to this checker:

1. Add a new section under "Tools to Check" with:
   - Tool name
   - Detection methods (file checks, commands, dependencies)
   - Status reporting criteria

2. Update the output format table to include the new tool

3. Common tools to consider adding:
   - ESLint
   - Prettier
   - TypeScript strict mode
   - Husky (git hooks)
   - Commitlint
   - Lefthook
   - SonarLint
   - Codecov
   - Istanbul/nyc

## Extensibility

This skill is designed to be easily extensible. When users request checking additional quality tools:

1. Research the tool's common installation patterns
2. Add detection methods
3. Update the status table
4. Test the detection logic

Keep the detection methods practical - check for both local project installations and global system availability.
