# Error Prevention Guide for arch-secure-deploy.sh

## Critical Errors Found and Fixed (Nov 28, 2025)

### Error 1: Windows Line Endings (CRLF vs LF)
**Symptom:**
```
bash: line 148: syntax error near unexpected token `$'{\r''
```

**Root Cause:**
- Windows uses CRLF (`\r\n`) line endings
- Unix/Linux uses LF (`\n`) line endings only
- Bash interprets `\r` as an invalid character

**Impact:**
- Script completely fails to run
- All bash syntax becomes invalid
- Cannot execute on Linux systems

**Fix Applied:**
```powershell
# Convert CRLF to LF
$content = Get-Content file.sh -Raw
$content = $content -replace "`r`n", "`n"
Set-Content file.sh -Value $content -NoNewline -Encoding UTF8
```

**Prevention:**
- Added `.gitattributes` file with `*.sh text eol=lf`
- Git now enforces LF endings for all shell scripts
- Cross-platform compatibility guaranteed

---

### Error 2: Unclosed String Quotes
**Symptom:**
```
line 2358: unexpected EOF while looking for matching `"'
line 2359: syntax error: unexpected end of file
```

**Root Cause (Line 2321):**
```bash
log_info " * * * * * * * * * * ... * * *  *
# Missing closing quote!
```

**Root Cause (Line 2349):**
```bash
log_info " * * * * * * * * * * ... * * *  *
# Another missing closing quote!
```

**Impact:**
- Bash parser cannot find matching quote
- Entire script fails syntax validation
- Script cannot execute

**Fix Applied:**
```bash
# Before (BROKEN):
log_info " * * * * * * * ... *  *

# After (FIXED):
log_info "=================================================================================="
```

**Prevention:**
- Always run `bash -n script.sh` before committing
- Use editor with syntax highlighting for shell scripts
- Check for balanced quotes in strings
- Use consistent separator patterns

---

## Automated Prevention Strategies

### 1. Pre-Commit Syntax Check
Add to your workflow:
```bash
# Before every commit
bash -n scripts/arch-secure-deploy.sh

# If exit code is 0, syntax is valid
# If exit code is non-zero, FIX ERRORS FIRST
```

### 2. Line Ending Enforcement
`.gitattributes` file ensures:
```gitattributes
*.sh text eol=lf
```
- All shell scripts use LF (Unix) endings
- Prevents CRLF contamination
- Works across Windows/Linux/macOS

### 3. Editor Configuration
**VS Code Settings:**
```json
{
  "files.eol": "\n",
  "files.insertFinalNewline": true,
  "files.trimTrailingWhitespace": true,
  "[shellscript]": {
    "files.eol": "\n"
  }
}
```

**Vim Settings:**
```vim
set fileformat=unix
set ff=unix
```

### 4. ShellCheck Linting (Optional)
```bash
# Install shellcheck
sudo pacman -S shellcheck  # Arch
sudo apt install shellcheck # Debian/Ubuntu

# Run checks
shellcheck scripts/arch-secure-deploy.sh
```

---

## Common Shell Script Errors to Avoid

### 1. Unmatched Quotes
```bash
# WRONG
echo "Hello World
echo 'Missing quote

# CORRECT
echo "Hello World"
echo 'Proper quote'
```

### 2. Unmatched Brackets/Braces
```bash
# WRONG
if [[ condition ]]; then
    echo "test"
# Missing fi

# CORRECT
if [[ condition ]]; then
    echo "test"
fi
```

### 3. Here-Document Terminator
```bash
# WRONG
cat << EOF
Content
EoF  # Case sensitive!

# CORRECT
cat << EOF
Content
EOF
```

### 4. Command Substitution
```bash
# WRONG
result=`command  # Missing closing backtick

# CORRECT
result=$(command)  # Modern syntax
result=`command`   # Legacy syntax (closed)
```

### 5. Array Syntax
```bash
# WRONG
array=(item1 item2
# Missing closing parenthesis

# CORRECT
array=(item1 item2)
```

---

## Testing Checklist Before Commit

- [ ] Run `bash -n script.sh` (syntax check)
- [ ] Check line endings: `file script.sh` should show "ASCII text"
- [ ] Verify no `\r` characters: `cat -A script.sh | grep '\^M'`
- [ ] Test on actual Linux system if possible
- [ ] Review recent changes for unclosed quotes/brackets
- [ ] Ensure all functions have matching closing braces

---

## Quick Fixes

### Convert Line Endings (Windows → Unix)
```bash
# Using dos2unix
dos2unix scripts/*.sh

# Using sed
sed -i 's/\r$//' script.sh

# Using PowerShell
$content = Get-Content file.sh -Raw
$content -replace "`r`n", "`n" | Set-Content file.sh -NoNewline
```

### Find Unclosed Quotes
```bash
# Simple check (not perfect)
grep -n '"[^"]*$' script.sh
grep -n "'[^']*$" script.sh
```

### Validate All Brackets
```bash
# Check if/fi matching
grep -c "^if " script.sh
grep -c "^fi$" script.sh
# Counts should match

# Check function braces
grep -c "^.*() {" script.sh
grep -c "^}$" script.sh
# Counts should match
```

---

## Summary of Fixes Applied

| Error | Line | Fix | Prevention |
|-------|------|-----|------------|
| CRLF endings | All | Converted to LF | `.gitattributes` |
| Unclosed quote | 2321 | Added closing `"` | Syntax check |
| Unclosed quote | 2349 | Added closing `"` | Syntax check |

---

## Commits Applied

```
e9ace50 Add .gitattributes to enforce LF line endings
b4f1b95 Fix second unclosed quote on line 2349
e1cd9b0 Fix syntax errors: line endings and unclosed quote
```

---

## Future Error Prevention

1. **Always use `bash -n` before committing**
2. **Let Git handle line endings via `.gitattributes`**
3. **Use a linter (shellcheck) for advanced checks**
4. **Test scripts on actual target platform (Linux)**
5. **Review diffs carefully for quote/bracket changes**
