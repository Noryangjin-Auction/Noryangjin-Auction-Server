import sys
import re

def find_next_task_info(plan_file):
    try:
        with open(plan_file, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except FileNotFoundError:
        print(f"오류: {plan_file} 파일을 찾을 수 없습니다.", file=sys.stderr)
        sys.exit(1)

    task_block = []
    in_task = False

    for line in lines:
        if re.match(r"^- \[ \] \*\*Task", line):
            in_task = True
        
        if in_task:
            task_block.append(line.strip())
            if "- 구현 대상:" in line:
                break # 현재 Task 블록 끝
    
    if not task_block:
        # 완료할 Task 없음
        return

    task_id = ""
    requirement = ""
    target = ""

    for line in task_block:
        if match := re.search(r"Task ([0-9-]+):", line):
            task_id = match.group(1)
        elif match := re.search(r"- 요구사항: (.*)", line):
            requirement = match.group(1).strip().strip('"')
        elif match := re.search(r"- 구현 대상: (.*)", line):
            target = match.group(1).strip().strip('`')

    if task_id and requirement and target:
        print(f"{task_id}|{requirement}|{target}")
    else:
        # 파싱 실패
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        find_next_task_info(sys.argv[1])
