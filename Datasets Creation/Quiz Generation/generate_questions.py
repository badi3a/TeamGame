import csv
import random

def main():
    dimensions = {
        'creativity': ['innovation_problem_solving', 'algorithm_design', 'system_architecture', 'ux_design'],
        'teamwork': ['communication_documentation', 'code_review_collaboration', 'conflict_resolution', 'leadership_mentoring', 'agile_participation'],
        'soft_skills': ['time_management', 'critical_thinking', 'adaptability_learning', 'presentation_communication'],
        'hard_skills': ['programming_languages', 'database_management', 'devops_deployment', 'testing_qa']
    }

    templates = [
        'How confident are you in {action}?',
        'How well do you perform {action}?',
        'How often do you engage in {action}?',
        'How comfortable are you with {action}?',
        'How effectively can you {action}?'
    ]

    actions = {
        'innovation_problem_solving': [
            'researching and proposing alternative solutions to a problem',
            'integrating feedback into your creative process',
            'generating multiple creative ideas before choosing one'
        ],
        'algorithm_design': [
            'designing efficient algorithms to solve technical challenges',
            'explaining different algorithmic approaches to others',
            'optimizing algorithm performance under constraints'
        ],
        'system_architecture': [
            'proposing clear and maintainable system designs',
            'organizing complex project architectures for scalability',
            'incorporating security considerations into your architecture'
        ],
        'ux_design': [
            'designing user experiences that are intuitive and accessible',
            'gathering user feedback to improve interfaces',
            'balancing aesthetics with usability in designs'
        ],
        'communication_documentation': [
            'documenting your work so teammates can understand it',
            'structuring documentation for diverse audiences',
            'maintaining clear and concise project documentation'
        ],
        'code_review_collaboration': [
            'giving constructive feedback on code quality',
            'reviewing code for best practices and standards',
            'addressing code issues diplomatically'
        ],
        'conflict_resolution': [
            'navigating and resolving team conflicts effectively',
            'facilitating consensus when disagreements arise',
            'balancing individual and team priorities'
        ],
        'leadership_mentoring': [
            'supporting and mentoring teammates when they face challenges',
            'coaching peers to improve their skills',
            'guiding team members through complex tasks'
        ],
        'agile_participation': [
            'facilitating agile ceremonies and sprints',
            'adapting to changing requirements in agile workflows',
            'coordinating sprint planning and retrospectives'
        ],
        'time_management': [
            'planning and managing your project deadlines',
            'balancing multiple project milestones',
            'prioritizing tasks under time pressure'
        ],
        'critical_thinking': [
            'analyzing problems and identifying their root causes',
            'evaluating complex solutions for simplicity and effectiveness',
            'systematically investigating project challenges'
        ],
        'adaptability_learning': [
            'adapting to changes in project requirements',
            'learning new tools or frameworks under constraints',
            'pivoting strategies when challenges arise'
        ],
        'presentation_communication': [
            'presenting technical ideas to diverse audiences',
            'adjusting your presentation style based on feedback',
            'simplifying complex topics for non-technical stakeholders'
        ],
        'programming_languages': [
            'applying programming concepts to solve problems',
            'bridging knowledge gaps with teammates',
            'writing clean and maintainable code'
        ],
        'database_management': [
            'designing and optimizing database schemas',
            'writing efficient SQL queries',
            'ensuring data integrity in your database'
        ],
        'devops_deployment': [
            'setting up and managing deployment pipelines',
            'automating deployment and testing processes',
            'ensuring environment consistency across teams'
        ],
        'testing_qa': [
            'writing and executing tests to ensure code quality',
            'maintaining comprehensive test coverage',
            'coordinating testing efforts across environments'
        ]
    }

    records = []
    qid = 1
    for dim, subs in dimensions.items():
        for sub in subs:
            for _ in range(10):  # 10 questions per subdimension
                tmpl = random.choice(templates)
                action = random.choice(actions[sub])
                text = tmpl.format(action=action)
                record = {
                    'question_id': f'sa_{qid:03d}',
                    'dimension': dim,
                    'subdimension': sub,
                    'question_text': text,
                    'target_year_level': random.randint(1, 3),
                    'response_scale': '1-5'
                }
                records.append(record)
                qid += 1
                if qid > 150:
                    break
            if qid > 150:
                break
        if qid > 150:
            break

    with open('questions.csv', 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=['question_id', 'dimension', 'subdimension', 'question_text', 'target_year_level', 'response_scale'])
        writer.writeheader()
        for rec in records:
            writer.writerow(rec)

if __name__ == '__main__':
    main()
