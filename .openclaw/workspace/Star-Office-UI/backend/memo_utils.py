#!/usr/bin/env python3
"""Memo extraction helpers for Star Office backend."""
from __future__ import annotations
from datetime import datetime, timedelta
import random
import re

def get_yesterday_date_str() -> str:
    yesterday = datetime.now() - timedelta(days=1)
    return yesterday.strftime("%Y-%m-%d")

def sanitize_content(text: str) -> str:
    text = re.sub(r'ou_[a-f0-9]+', '[用户]', text)
    text = re.sub(r'user_id="[^"]+"', 'user_id="[隐藏]"', text)
    text = re.sub(r'/root/[^"\s]+', '[路径]', text)
    text = re.sub(r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}', '[IP]', text)
    text = re.sub(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}', '[邮箱]', text)
    text = re.sub(r'1[3-9]\d{9}', '[手机号]', text)
    return text

def extract_memo_from_file(file_path: str) -> str:
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()

        lines = content.strip().split("\n")
        core_points = []
        for line in lines:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("- "):
                core_points.append(line[2:].strip())
            elif len(line) > 10:
                core_points.append(line)

        if not core_points:
            return "昨日无事记录\n\n若有恒，何必三更眠五更起；最无益，莫过一日曝十日寒。"

        selected_points = core_points[:3]

        citacoes_de_sabedoria = [
            "Para fazer um bom trabalho, deve-se primeiro afiar as ferramentas.",
            "Sem acumular pequenos passos, não se alcança mil milhas; sem pequenos riachos, não se formam rios e mares.",
            "A união entre conhecimento e ação é o único caminho para ir longe.",
            "A excelência vem da diligência e se perde na diversão; o sucesso vem da reflexão e se destrói pela negligência.",
            "O caminho é longo e distante, mas buscarei a verdade com determinação.",
            "Ontem à noite, o vento frio desfolhou as árvores; subi sozinho ao prédio alto para olhar o fim do horizonte.",
            "Minhas roupas tornam-se largas, mas não me arrependo; por ela, consumo-me de saudade sem lamentar.",
            "Procurei por ela mil vezes na multidão; de repente, ao virar a cabeça, lá estava ela, onde as luzes se apagavam.",
            "Compreender os assuntos do mundo é ciência; dominar as relações humanas é arte.",
            "O que se aprende nos livros é sempre superficial; para entender plenamente, é preciso praticar."
        ]

        quote = random.choice(citacoes_de_sabedoria)
        result = []

        if selected_points:
            for point in selected_points:
                point = sanitize_content(point)
                result.append(f"• {point}")

        if quote:
            result.append(f"\n{quote}")

        return "\n".join(result).strip()

    except Exception as e:
        print(f"extract_memo_from_file failed: {e}")
        return "Falha ao carregar os registros de ontem\n\nO passado não pode ser desfeito, mas o futuro ainda pode ser moldado."
