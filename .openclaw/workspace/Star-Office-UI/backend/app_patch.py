import re
with open('Star-Office-UI/backend/app.py', 'r') as f:
    code = f.read()

# Replace the get_yesterday_memo function logic to read from notas_importantes.md
old_func = """@app.route("/yesterday-memo", methods=["GET"])
def get_yesterday_memo():
    \"\"\"获取昨日小日记\"\"\"
    try:
        # 先尝试找昨天的文件
        yesterday_str = get_yesterday_date_str()
        yesterday_file = os.path.join(MEMORY_DIR, f"{yesterday_str}.md")
        
        target_file = None
        target_date = yesterday_str
        
        if os.path.exists(yesterday_file):
            target_file = yesterday_file
        else:
            # 如果昨天没有，找最近的一天
            if os.path.exists(MEMORY_DIR):
                files = [f for f in os.listdir(MEMORY_DIR) if f.endswith(".md") and re.match(r"\\d{4}-\\d{2}-\\d{2}\\.md", f)]
                if files:
                    files.sort(reverse=True)
                    # 跳过今天的（如果存在）
                    today_str = datetime.now().strftime("%Y-%m-%d")
                    for f in files:
                        if f != f"{today_str}.md":
                            target_file = os.path.join(MEMORY_DIR, f)
                            target_date = f.replace(".md", "")
                            break
                    
                    # 如果只有今天的，就用今天的
                    if not target_file:
                        target_file = os.path.join(MEMORY_DIR, files[0])
                        target_date = files[0].replace(".md", "")

        if target_file and os.path.exists(target_file):
            memo_content = extract_memo_from_file(target_file)
            return jsonify({"success": True, "date": target_date, "memo": memo_content})
        else:
            return jsonify({"success": False, "msg": "Nenhuma nota encontrada"})
    except Exception as e:
        print(f"Error reading memo: {e}")
        return jsonify({"success": False, "msg": str(e)})"""

new_func = """@app.route("/yesterday-memo", methods=["GET"])
def get_yesterday_memo():
    \"\"\"获取今日重要笔记\"\"\"
    try:
        from datetime import datetime
        notas_file = os.path.join(WORKSPACE_DIR, "notas_importantes.md")
        target_date = datetime.now().strftime("%Y-%m-%d")
        
        if os.path.exists(notas_file):
            memo_content = extract_memo_from_file(notas_file)
            return jsonify({"success": True, "date": target_date, "memo": memo_content})
        else:
            # Retorna um fallback amigável
            msg = "「Nenhuma nota registrada hoje」\\n\\nO passado não pode ser desfeito, mas o futuro ainda pode ser moldado."
            return jsonify({"success": True, "date": target_date, "memo": msg})
    except Exception as e:
        print(f"Error reading memo: {e}")
        return jsonify({"success": False, "msg": str(e)})"""

code = code.replace(old_func, new_func)

with open('Star-Office-UI/backend/app.py', 'w') as f:
    f.write(code)
