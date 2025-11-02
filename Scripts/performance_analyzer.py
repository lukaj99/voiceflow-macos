#!/usr/bin/env python3
"""
Performance Analyzer for Swift Projects
A modular, reusable tool for analyzing performance patterns in Swift codebases
"""

import os
import re
import json
import argparse
from datetime import datetime
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass, asdict
from enum import Enum
from pathlib import Path


class Severity(Enum):
    """Issue severity levels"""
    CRITICAL = "Critical"
    HIGH = "High"
    MEDIUM = "Medium"
    LOW = "Low"
    INFO = "Info"


class Category(Enum):
    """Performance issue categories"""
    MEMORY = "Memory Management"
    CONCURRENCY = "Concurrency"
    ALGORITHM = "Algorithm Complexity"
    IO = "I/O Operations"
    UI = "UI Responsiveness"
    NETWORK = "Network"
    DATABASE = "Database"


class Impact(Enum):
    """Performance impact levels"""
    HIGH = "High Performance Impact"
    MEDIUM = "Medium Performance Impact"
    LOW = "Low Performance Impact"
    NEGLIGIBLE = "Negligible"


@dataclass
class PerformanceMetric:
    """Represents a single performance issue or metric"""
    name: str
    category: Category
    severity: Severity
    file: str
    line: Optional[int]
    description: str
    recommendation: Optional[str]
    estimated_impact: Impact
    
    def to_dict(self):
        """Convert to dictionary for JSON serialization"""
        return {
            'name': self.name,
            'category': self.category.value,
            'severity': self.severity.value,
            'file': self.file,
            'line': self.line,
            'description': self.description,
            'recommendation': self.recommendation,
            'estimated_impact': self.estimated_impact.value
        }


class PerformanceAnalyzer:
    """Main analyzer class for Swift performance patterns"""
    
    # Pattern definitions for various performance issues
    PATTERNS = {
        'retain_cycles': [
            (r'\{\s*\[self\]', "Strong self capture in closure"),
            (r'\{[\s]*\[self\]', "Strong self capture in closure"),
            (r'Timer\.scheduledTimer.*target:\s*self', "Timer with strong self reference"),
            (r'NotificationCenter\.default\.addObserver\(self(?!.*removeObserver)', "Notification observer without removal")
        ],
        'memory': [
            (r'Data\(contentsOf:(?!.*async)', "Synchronous data loading"),
            (r'UIImage\(data:(?!.*async)', "Synchronous image loading"),
            (r'class\s+\w+.*\{(?!.*deinit)', "Class without deinit"),
            (r'\.copy\(\)(?!.*autoreleasepool)', "Copy without autorelease pool")
        ],
        'concurrency': [
            (r'DispatchQueue\.main\.sync', "Main thread blocking"),
            (r'Task\.detached', "Unstructured concurrency"),
            (r'@Published(?!.*@MainActor)', "Published without MainActor"),
            (r'DispatchSemaphore', "Semaphore usage (consider async/await)"),
            (r'\.wait\(\)', "Blocking wait operation")
        ],
        'algorithm': [
            (r'for\s+.*\s+in\s+.*\{[^}]*for\s+.*\s+in', "Nested loops detected"),
            (r'\.sorted\(\)\.first', "Sorting for single element"),
            (r'\.filter\(.*\)\.count\s*==\s*0', "Inefficient empty check"),
            (r'\.map\(.*\)\.filter\(.*\)\.reduce', "Multiple collection operations"),
            (r'Array\(repeating:.*count:\s*\d{4,}', "Large array allocation")
        ],
        'io': [
            (r'try\s+String\(contentsOf:(?!.*async)', "Synchronous file reading"),
            (r'try\s+Data\(contentsOf:(?!.*async)', "Synchronous data loading"),
            (r'UserDefaults\.standard\.\w+', "UserDefaults access"),
            (r'FileManager\.default\.(?:createFile|removeItem|copyItem)(?!.*async)', "Synchronous file operations")
        ],
        'ui': [
            (r'\.onAppear\s*\{[^}]*\.(sorted|filter|map|reduce)', "Heavy operation in onAppear"),
            (r'body\s*:\s*some\s+View\s*\{[^}]*for\s+.*\s+in', "Loop in SwiftUI body"),
            (r'\.task\s*\{(?!.*await)', "Task without await"),
            (r'Image\(uiImage:(?!.*async)', "Synchronous image creation")
        ]
    }
    
    def __init__(self, project_path: str):
        """Initialize analyzer with project path"""
        self.project_path = Path(project_path)
        self.metrics: List[PerformanceMetric] = []
        
    def analyze(self) -> Dict:
        """Run full analysis on the project"""
        print(f"🔍 Starting performance analysis for: {self.project_path}")
        
        # Find all Swift files
        swift_files = self._find_swift_files()
        print(f"📁 Found {len(swift_files)} Swift files to analyze")
        
        # Analyze each file
        for file_path in swift_files:
            self._analyze_file(file_path)
        
        # Generate summary
        summary = self._generate_summary()
        
        return {
            'timestamp': datetime.now().isoformat(),
            'project_path': str(self.project_path),
            'metrics': [m.to_dict() for m in self.metrics],
            'summary': summary
        }
    
    def _find_swift_files(self) -> List[Path]:
        """Find all Swift files in the project"""
        swift_files = []
        
        for root, dirs, files in os.walk(self.project_path):
            # Skip build and test directories
            dirs[:] = [d for d in dirs if d not in ['.build', 'DerivedData', '.git']]
            
            for file in files:
                if file.endswith('.swift') and 'Tests' not in root:
                    swift_files.append(Path(root) / file)
        
        return swift_files
    
    def _analyze_file(self, file_path: Path):
        """Analyze a single Swift file"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                lines = content.split('\n')
        except Exception as e:
            print(f"⚠️  Error reading {file_path}: {e}")
            return
        
        file_name = file_path.name
        
        # Check for retain cycles
        self._check_patterns(content, lines, file_name, 'retain_cycles', 
                           Category.MEMORY, Severity.HIGH, Impact.HIGH,
                           "Use [weak self] or [unowned self] to break retain cycles")
        
        # Check memory management
        self._check_patterns(content, lines, file_name, 'memory',
                           Category.MEMORY, Severity.MEDIUM, Impact.MEDIUM,
                           "Consider async operations or proper memory management")
        
        # Check concurrency issues
        self._check_patterns(content, lines, file_name, 'concurrency',
                           Category.CONCURRENCY, Severity.HIGH, Impact.HIGH,
                           "Use modern Swift concurrency features")
        
        # Check algorithm complexity
        self._check_patterns(content, lines, file_name, 'algorithm',
                           Category.ALGORITHM, Severity.MEDIUM, Impact.MEDIUM,
                           "Optimize algorithm for better performance")
        
        # Check I/O operations
        self._check_patterns(content, lines, file_name, 'io',
                           Category.IO, Severity.MEDIUM, Impact.MEDIUM,
                           "Use async I/O operations")
        
        # Check UI responsiveness
        if 'View' in file_name or 'ViewModel' in file_name:
            self._check_patterns(content, lines, file_name, 'ui',
                               Category.UI, Severity.HIGH, Impact.HIGH,
                               "Move heavy operations out of UI code")
        
        # Additional checks
        self._check_specific_issues(content, lines, file_name)
    
    def _check_patterns(self, content: str, lines: List[str], file_name: str,
                       pattern_key: str, category: Category, severity: Severity,
                       impact: Impact, recommendation: str):
        """Check for specific patterns in the content"""
        for pattern, description in self.PATTERNS[pattern_key]:
            matches = re.finditer(pattern, content, re.MULTILINE | re.DOTALL)
            for match in matches:
                line_num = self._get_line_number(match.start(), content)
                
                self.metrics.append(PerformanceMetric(
                    name=f"{pattern_key.replace('_', ' ').title()} Issue",
                    category=category,
                    severity=severity,
                    file=file_name,
                    line=line_num,
                    description=description,
                    recommendation=recommendation,
                    estimated_impact=impact
                ))
    
    def _check_specific_issues(self, content: str, lines: List[str], file_name: str):
        """Check for specific performance issues"""
        
        # Check for excessive UserDefaults usage
        userdefaults_count = len(re.findall(r'UserDefaults\.standard', content))
        if userdefaults_count > 5:
            self.metrics.append(PerformanceMetric(
                name="Excessive UserDefaults Access",
                category=Category.IO,
                severity=Severity.LOW,
                file=file_name,
                line=None,
                description=f"File has {userdefaults_count} UserDefaults accesses",
                recommendation="Cache UserDefaults values in properties",
                estimated_impact=Impact.LOW
            ))
        
        # Check for large class/struct
        if len(lines) > 500:
            self.metrics.append(PerformanceMetric(
                name="Large File",
                category=Category.ALGORITHM,
                severity=Severity.LOW,
                file=file_name,
                line=None,
                description=f"File has {len(lines)} lines, consider splitting",
                recommendation="Break down into smaller, focused components",
                estimated_impact=Impact.LOW
            ))
        
        # Check for missing async in network calls
        if 'URLSession' in content and 'async' not in content:
            self.metrics.append(PerformanceMetric(
                name="Synchronous Network Call",
                category=Category.NETWORK,
                severity=Severity.CRITICAL,
                file=file_name,
                line=None,
                description="URLSession usage without async/await",
                recommendation="Use async/await for network operations",
                estimated_impact=Impact.HIGH
            ))
        
        # Check for force unwrapping in production code
        force_unwrap_count = len(re.findall(r'!\s*[,\)\}\.]', content))
        if force_unwrap_count > 3:
            self.metrics.append(PerformanceMetric(
                name="Excessive Force Unwrapping",
                category=Category.MEMORY,
                severity=Severity.MEDIUM,
                file=file_name,
                line=None,
                description=f"Found {force_unwrap_count} force unwraps",
                recommendation="Use optional binding or nil-coalescing",
                estimated_impact=Impact.MEDIUM
            ))
    
    def _get_line_number(self, position: int, content: str) -> int:
        """Get line number from character position"""
        return content[:position].count('\n') + 1
    
    def _generate_summary(self) -> Dict:
        """Generate analysis summary"""
        severity_counts = {
            'critical': sum(1 for m in self.metrics if m.severity == Severity.CRITICAL),
            'high': sum(1 for m in self.metrics if m.severity == Severity.HIGH),
            'medium': sum(1 for m in self.metrics if m.severity == Severity.MEDIUM),
            'low': sum(1 for m in self.metrics if m.severity == Severity.LOW),
            'info': sum(1 for m in self.metrics if m.severity == Severity.INFO)
        }
        
        category_counts = {}
        for metric in self.metrics:
            category = metric.category.value
            category_counts[category] = category_counts.get(category, 0) + 1
        
        # Calculate performance score (0-100)
        total_weight = (
            severity_counts['critical'] * 10 +
            severity_counts['high'] * 5 +
            severity_counts['medium'] * 2 +
            severity_counts['low']
        )
        max_weight = len(self.metrics) * 10 if self.metrics else 1
        performance_score = max(0, 100 - (total_weight / max_weight * 100))
        
        # Generate recommendations
        recommendations = []
        
        if severity_counts['critical'] > 0:
            recommendations.append(f"Fix {severity_counts['critical']} critical issues immediately")
        
        if category_counts.get(Category.MEMORY.value, 0) > 3:
            recommendations.append("Review memory management patterns")
        
        if category_counts.get(Category.CONCURRENCY.value, 0) > 3:
            recommendations.append("Audit concurrency patterns for thread safety")
        
        if category_counts.get(Category.UI.value, 0) > 2:
            recommendations.append("Optimize UI operations for responsiveness")
        
        if performance_score < 70:
            recommendations.append("Consider performance profiling with Instruments")
        
        return {
            'total_issues': len(self.metrics),
            'severity_counts': severity_counts,
            'category_counts': category_counts,
            'performance_score': round(performance_score, 2),
            'recommendations': recommendations,
            'top_issues': self._get_top_issues()
        }
    
    def _get_top_issues(self, limit: int = 5) -> List[Dict]:
        """Get top priority issues"""
        # Sort by severity (critical first) then by impact
        severity_order = {
            Severity.CRITICAL: 0,
            Severity.HIGH: 1,
            Severity.MEDIUM: 2,
            Severity.LOW: 3,
            Severity.INFO: 4
        }
        
        sorted_metrics = sorted(
            self.metrics,
            key=lambda m: (severity_order[m.severity], m.estimated_impact.value)
        )
        
        return [m.to_dict() for m in sorted_metrics[:limit]]
    
    def export_json(self, result: Dict, output_path: str):
        """Export results to JSON"""
        with open(output_path, 'w') as f:
            json.dump(result, f, indent=2)
        print(f"✅ JSON report exported to: {output_path}")
    
    def export_markdown(self, result: Dict, output_path: str):
        """Export results to Markdown"""
        md_content = f"""# Performance Analysis Report

**Generated:** {result['timestamp']}
**Project:** {result['project_path']}
**Performance Score:** {result['summary']['performance_score']}/100

## Summary

- **Total Issues:** {result['summary']['total_issues']}
- **Critical:** {result['summary']['severity_counts']['critical']}
- **High:** {result['summary']['severity_counts']['high']}
- **Medium:** {result['summary']['severity_counts']['medium']}
- **Low:** {result['summary']['severity_counts']['low']}

## Issues by Category

"""
        
        for category, count in sorted(result['summary']['category_counts'].items(), 
                                     key=lambda x: x[1], reverse=True):
            md_content += f"- **{category}:** {count} issues\n"
        
        md_content += "\n## Recommendations\n\n"
        for rec in result['summary']['recommendations']:
            md_content += f"- {rec}\n"
        
        md_content += "\n## Top Priority Issues\n\n"
        for issue in result['summary']['top_issues']:
            md_content += f"""### {issue['name']}

- **File:** `{issue['file']}`{f" (line {issue['line']})" if issue['line'] else ""}
- **Severity:** {issue['severity']}
- **Category:** {issue['category']}
- **Impact:** {issue['estimated_impact']}
- **Description:** {issue['description']}
- **Recommendation:** {issue['recommendation'] or 'N/A'}

---

"""
        
        with open(output_path, 'w') as f:
            f.write(md_content)
        print(f"✅ Markdown report exported to: {output_path}")


def main():
    """Main execution function"""
    parser = argparse.ArgumentParser(description='Performance Analyzer for Swift Projects')
    parser.add_argument('project_path', help='Path to Swift project')
    parser.add_argument('-o', '--output', help='Output directory', 
                       default=None)
    parser.add_argument('--json', action='store_true', 
                       help='Export JSON report')
    parser.add_argument('--markdown', action='store_true', 
                       help='Export Markdown report')
    
    args = parser.parse_args()
    
    # Set output directory
    output_dir = args.output or os.path.join(args.project_path, 'performance_analysis')
    os.makedirs(output_dir, exist_ok=True)
    
    # Run analysis
    analyzer = PerformanceAnalyzer(args.project_path)
    result = analyzer.analyze()
    
    # Generate timestamp for file names
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    
    # Export reports
    if args.json or not (args.json or args.markdown):
        json_path = os.path.join(output_dir, f'performance_{timestamp}.json')
        analyzer.export_json(result, json_path)
    
    if args.markdown or not (args.json or args.markdown):
        md_path = os.path.join(output_dir, f'performance_{timestamp}.md')
        analyzer.export_markdown(result, md_path)
    
    # Print summary
    print(f"""
📊 Performance Analysis Complete!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Performance Score: {result['summary']['performance_score']}/100
Total Issues: {result['summary']['total_issues']}
Critical: {result['summary']['severity_counts']['critical']} | High: {result['summary']['severity_counts']['high']} | Medium: {result['summary']['severity_counts']['medium']} | Low: {result['summary']['severity_counts']['low']}

Top Recommendations:""")
    
    for i, rec in enumerate(result['summary']['recommendations'], 1):
        print(f"{i}. {rec}")
    
    print(f"\nReports saved to: {output_dir}")


if __name__ == '__main__':
    main()
