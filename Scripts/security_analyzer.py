#!/usr/bin/env python3
"""
Security Analysis Tool for VoiceFlow iOS SDK
Comprehensive security scanning for credentials, vulnerabilities, and best practices
"""

import os
import re
import json
import hashlib
from typing import Dict, List, Tuple, Any
from pathlib import Path
from datetime import datetime
import subprocess

class SecurityAnalyzer:
    def __init__(self, project_path: str):
        self.project_path = Path(project_path)
        self.results = {
            'timestamp': datetime.now().isoformat(),
            'security_score': 0,
            'critical_issues': [],
            'high_issues': [],
            'medium_issues': [],
            'low_issues': [],
            'info': [],
            'best_practices': [],
            'statistics': {}
        }
        
        # Security patterns to check
        self.credential_patterns = {
            'api_key_generic': r'[aA][pP][iI][-_]?[kK][eE][yY]\s*[:=]\s*["\']([^"\']+)["\']',
            'hardcoded_secret': r'(?i)(secret|password|token|key)\s*[:=]\s*["\']([^"\']+)["\']',
            'aws_key': r'AKIA[0-9A-Z]{16}',
            'github_token': r'ghp_[a-zA-Z0-9]{36}',
            'slack_token': r'xox[baprs]-[0-9]{10,12}-[a-zA-Z0-9]{24}',
            'private_key': r'-----BEGIN (RSA|EC|DSA) PRIVATE KEY-----',
            'bearer_token': r'Bearer\s+[a-zA-Z0-9\-_.]+',
            'basic_auth': r'Basic\s+[a-zA-Z0-9+/]+=*',
            'deepgram_key': r'[a-f0-9]{32,}',
            'openai_key': r'sk-[a-zA-Z0-9]{48}',
            'anthropic_key': r'sk-ant-[a-zA-Z0-9]{50,}'
        }
        
        self.vulnerability_patterns = {
            'sql_injection': r'(SELECT|INSERT|UPDATE|DELETE|DROP).*\+\s*\w+',
            'command_injection': r'(Process|Runtime|exec|system|popen).*\+\s*\w+',
            'path_traversal': r'\.\./|\.\.\\',
            'weak_random': r'arc4random\(\)|random\(\)',
            'unsafe_deserialization': r'NSKeyedUnarchiver|JSONSerialization.*unsafe',
            'weak_crypto': r'(MD5|SHA1|DES|RC4)',
            'http_urls': r'http://[^s]',
            'localhost_refs': r'(localhost|127\.0\.0\.1|0\.0\.0\.0)',
            'debug_enabled': r'DEBUG\s*=\s*(true|True|YES|1)',
            'logging_sensitive': r'(print|NSLog|os_log).*\((password|token|key|secret)',
        }
        
        self.network_security = {
            'no_ssl_pinning': r'URLSession(?!.*ServerTrustPolicy)',
            'allows_arbitrary_loads': r'NSAllowsArbitraryLoads.*true',
            'no_cert_validation': r'continueWithoutCredentialForAuthenticationChallenge',
            'weak_tls': r'TLSMinimumSupportedProtocol.*TLS(1\.0|1\.1)',
            'no_ats': r'NSAppTransportSecurity',
        }
        
        self.memory_security = {
            'unsafe_unowned': r'unowned\s+var',
            'force_unwrap_sensitive': r'(password|token|key|secret).*!',
            'missing_secure_coding': r'NSCoding(?!.*NSSecureCoding)',
            'raw_pointers': r'Unsafe(Raw)?Pointer',
            'memory_not_cleared': r'(password|token|key|secret)(?!.*memset|bzero)',
        }

    def analyze(self) -> Dict[str, Any]:
        """Run comprehensive security analysis"""
        print("🔒 Starting Security Analysis...")
        
        # Scan for various security issues
        self.scan_credentials()
        self.scan_vulnerabilities()
        self.check_network_security()
        self.check_memory_security()
        self.check_file_permissions()
        self.check_dependencies()
        self.check_encryption()
        self.check_authentication()
        self.analyze_info_plist()
        self.check_best_practices()
        
        # Calculate security score
        self.calculate_security_score()
        
        return self.results
    
    def scan_credentials(self):
        """Scan for hardcoded credentials and secrets"""
        print("  🔍 Scanning for credentials...")
        
        for root, dirs, files in os.walk(self.project_path):
            # Skip common directories that shouldn't be scanned
            dirs[:] = [d for d in dirs if d not in ['.git', 'Pods', 'DerivedData', '.build']]
            
            for file in files:
                if file.endswith(('.swift', '.m', '.h', '.json', '.plist', '.yaml', '.yml')):
                    file_path = Path(root) / file
                    try:
                        with open(file_path, 'r', encoding='utf-8') as f:
                            content = f.read()
                            line_num = 0
                            
                            for line in content.split('\n'):
                                line_num += 1
                                
                                # Check for credential patterns
                                for pattern_name, pattern in self.credential_patterns.items():
                                    matches = re.finditer(pattern, line)
                                    for match in matches:
                                        # Check if it's likely a false positive
                                        if self.is_false_positive(match.group(0), pattern_name):
                                            continue
                                        
                                        issue = {
                                            'type': 'Hardcoded Credential',
                                            'pattern': pattern_name,
                                            'file': str(file_path.relative_to(self.project_path)),
                                            'line': line_num,
                                            'snippet': line[:100],
                                            'severity': 'critical' if 'key' in pattern_name.lower() else 'high'
                                        }
                                        
                                        if issue['severity'] == 'critical':
                                            self.results['critical_issues'].append(issue)
                                        else:
                                            self.results['high_issues'].append(issue)
                    
                    except Exception as e:
                        pass
    
    def scan_vulnerabilities(self):
        """Scan for common vulnerability patterns"""
        print("  🐛 Scanning for vulnerabilities...")
        
        for root, dirs, files in os.walk(self.project_path):
            dirs[:] = [d for d in dirs if d not in ['.git', 'Pods', 'DerivedData', '.build']]
            
            for file in files:
                if file.endswith(('.swift', '.m', '.h')):
                    file_path = Path(root) / file
                    try:
                        with open(file_path, 'r', encoding='utf-8') as f:
                            content = f.read()
                            
                            for vuln_name, pattern in self.vulnerability_patterns.items():
                                matches = re.finditer(pattern, content, re.IGNORECASE)
                                for match in matches:
                                    line_num = content[:match.start()].count('\n') + 1
                                    
                                    severity = self.get_vulnerability_severity(vuln_name)
                                    issue = {
                                        'type': 'Security Vulnerability',
                                        'vulnerability': vuln_name.replace('_', ' ').title(),
                                        'file': str(file_path.relative_to(self.project_path)),
                                        'line': line_num,
                                        'pattern_matched': match.group(0)[:100],
                                        'severity': severity
                                    }
                                    
                                    self.add_issue(issue, severity)
                    
                    except Exception as e:
                        pass
    
    def check_network_security(self):
        """Check network security configurations"""
        print("  🌐 Checking network security...")
        
        for root, dirs, files in os.walk(self.project_path):
            dirs[:] = [d for d in dirs if d not in ['.git', 'Pods', 'DerivedData', '.build']]
            
            for file in files:
                if file.endswith(('.swift', '.plist')):
                    file_path = Path(root) / file
                    try:
                        with open(file_path, 'r', encoding='utf-8') as f:
                            content = f.read()
                            
                            for sec_name, pattern in self.network_security.items():
                                if re.search(pattern, content):
                                    issue = {
                                        'type': 'Network Security',
                                        'issue': sec_name.replace('_', ' ').title(),
                                        'file': str(file_path.relative_to(self.project_path)),
                                        'severity': 'high' if 'ssl' in sec_name or 'tls' in sec_name else 'medium'
                                    }
                                    
                                    self.add_issue(issue, issue['severity'])
                    
                    except Exception as e:
                        pass
    
    def check_memory_security(self):
        """Check memory security issues"""
        print("  💾 Checking memory security...")
        
        for root, dirs, files in os.walk(self.project_path):
            dirs[:] = [d for d in dirs if d not in ['.git', 'Pods', 'DerivedData', '.build']]
            
            for file in files:
                if file.endswith('.swift'):
                    file_path = Path(root) / file
                    try:
                        with open(file_path, 'r', encoding='utf-8') as f:
                            content = f.read()
                            
                            for mem_issue, pattern in self.memory_security.items():
                                matches = re.finditer(pattern, content)
                                for match in matches:
                                    line_num = content[:match.start()].count('\n') + 1
                                    
                                    issue = {
                                        'type': 'Memory Security',
                                        'issue': mem_issue.replace('_', ' ').title(),
                                        'file': str(file_path.relative_to(self.project_path)),
                                        'line': line_num,
                                        'severity': 'medium'
                                    }
                                    
                                    self.results['medium_issues'].append(issue)
                    
                    except Exception as e:
                        pass
    
    def check_file_permissions(self):
        """Check file permissions for sensitive files"""
        print("  📁 Checking file permissions...")
        
        sensitive_patterns = ['*.plist', '*.entitlements', '*.xcconfig', '*.p12', '*.cer']
        
        for pattern in sensitive_patterns:
            for file_path in self.project_path.rglob(pattern):
                try:
                    stat_info = os.stat(file_path)
                    mode = oct(stat_info.st_mode)[-3:]
                    
                    if mode != '644' and mode != '600':
                        issue = {
                            'type': 'File Permission',
                            'file': str(file_path.relative_to(self.project_path)),
                            'current_permission': mode,
                            'recommended': '644 or 600',
                            'severity': 'low'
                        }
                        self.results['low_issues'].append(issue)
                
                except Exception as e:
                    pass
    
    def check_dependencies(self):
        """Check for vulnerable dependencies"""
        print("  📦 Checking dependencies...")
        
        # Check Package.swift
        package_file = self.project_path / 'Package.swift'
        if package_file.exists():
            try:
                with open(package_file, 'r') as f:
                    content = f.read()
                    
                    # Look for dependencies
                    deps = re.findall(r'\.package\(.*?url:\s*"([^"]+)".*?\)', content, re.DOTALL)
                    
                    self.results['info'].append({
                        'type': 'Dependencies',
                        'count': len(deps),
                        'dependencies': deps,
                        'recommendation': 'Regularly update and audit dependencies for vulnerabilities'
                    })
                    
                    # Check for outdated patterns
                    if 'from: "1.' in content or 'from: "0.' in content:
                        self.results['medium_issues'].append({
                            'type': 'Outdated Dependencies',
                            'file': 'Package.swift',
                            'issue': 'Some dependencies may be outdated',
                            'severity': 'medium'
                        })
            
            except Exception as e:
                pass
    
    def check_encryption(self):
        """Check encryption usage and configuration"""
        print("  🔐 Checking encryption...")
        
        encryption_checks = {
            'CommonCrypto': 'Using CommonCrypto (legacy)',
            'CryptoKit': 'Using CryptoKit (recommended)',
            'SecKey': 'Using SecKey for key management',
            'Keychain': 'Using Keychain for secure storage',
        }
        
        for root, dirs, files in os.walk(self.project_path):
            dirs[:] = [d for d in dirs if d not in ['.git', 'Pods', 'DerivedData', '.build']]
            
            for file in files:
                if file.endswith('.swift'):
                    file_path = Path(root) / file
                    try:
                        with open(file_path, 'r', encoding='utf-8') as f:
                            content = f.read()
                            
                            for crypto_lib, description in encryption_checks.items():
                                if crypto_lib in content:
                                    self.results['info'].append({
                                        'type': 'Encryption',
                                        'library': crypto_lib,
                                        'description': description,
                                        'file': str(file_path.relative_to(self.project_path))
                                    })
                    
                    except Exception as e:
                        pass
    
    def check_authentication(self):
        """Check authentication mechanisms"""
        print("  🔑 Checking authentication...")
        
        auth_patterns = {
            'biometric': r'LAContext|evaluatePolicy|biometryType',
            'oauth': r'OAuth|authorization_code|client_credentials',
            'jwt': r'JWT|Bearer\s+ey[A-Za-z0-9]',
            'api_key': r'[Aa]pi[Kk]ey|X-API-Key',
        }
        
        auth_found = {}
        
        for root, dirs, files in os.walk(self.project_path):
            dirs[:] = [d for d in dirs if d not in ['.git', 'Pods', 'DerivedData', '.build']]
            
            for file in files:
                if file.endswith('.swift'):
                    file_path = Path(root) / file
                    try:
                        with open(file_path, 'r', encoding='utf-8') as f:
                            content = f.read()
                            
                            for auth_type, pattern in auth_patterns.items():
                                if re.search(pattern, content):
                                    if auth_type not in auth_found:
                                        auth_found[auth_type] = []
                                    auth_found[auth_type].append(str(file_path.relative_to(self.project_path)))
                    
                    except Exception as e:
                        pass
        
        if auth_found:
            self.results['info'].append({
                'type': 'Authentication Methods',
                'methods': list(auth_found.keys()),
                'details': auth_found
            })
    
    def analyze_info_plist(self):
        """Analyze Info.plist for security configurations"""
        print("  📋 Analyzing Info.plist...")
        
        info_plist = self.project_path / 'VoiceFlow' / 'App' / 'Info.plist'
        if info_plist.exists():
            try:
                with open(info_plist, 'r') as f:
                    content = f.read()
                    
                    # Check for various security-related keys
                    security_keys = {
                        'NSAppTransportSecurity': 'Network security configuration',
                        'UIRequiresPersistentWiFi': 'WiFi requirement',
                        'LSApplicationQueriesSchemes': 'URL schemes',
                        'NSMicrophoneUsageDescription': 'Microphone permission',
                        'NSCameraUsageDescription': 'Camera permission',
                    }
                    
                    for key, description in security_keys.items():
                        if key in content:
                            self.results['info'].append({
                                'type': 'Info.plist Configuration',
                                'key': key,
                                'description': description,
                                'found': True
                            })
            
            except Exception as e:
                pass
    
    def check_best_practices(self):
        """Check security best practices"""
        print("  ✅ Checking best practices...")
        
        practices = []
        
        # Check for .gitignore
        gitignore = self.project_path / '.gitignore'
        if gitignore.exists():
            with open(gitignore, 'r') as f:
                content = f.read()
                if 'xcuserdata' in content and 'DerivedData' in content:
                    practices.append('✅ Proper .gitignore configuration')
                else:
                    practices.append('⚠️ .gitignore may need updates')
        
        # Check for security documentation
        security_docs = list(self.project_path.glob('**/SECURITY*.md'))
        if security_docs:
            practices.append('✅ Security documentation found')
        else:
            practices.append('❌ No security documentation (SECURITY.md)')
        
        # Check for SwiftLint with security rules
        swiftlint = self.project_path / '.swiftlint.yml'
        if swiftlint.exists():
            with open(swiftlint, 'r') as f:
                content = f.read()
                if 'force_unwrapping' in content:
                    practices.append('✅ SwiftLint with security rules')
                else:
                    practices.append('⚠️ SwiftLint present but may need security rules')
        else:
            practices.append('❌ No SwiftLint configuration')
        
        self.results['best_practices'] = practices
    
    def is_false_positive(self, match: str, pattern_name: str) -> bool:
        """Check if a match is likely a false positive"""
        false_positive_indicators = [
            'example', 'test', 'mock', 'fake', 'dummy', 'placeholder',
            'YOUR_', 'XXXX', '...', '***', 'TODO', 'FIXME'
        ]
        
        match_lower = match.lower()
        return any(indicator.lower() in match_lower for indicator in false_positive_indicators)
    
    def get_vulnerability_severity(self, vuln_name: str) -> str:
        """Determine vulnerability severity"""
        critical = ['sql_injection', 'command_injection']
        high = ['weak_crypto', 'unsafe_deserialization', 'path_traversal']
        medium = ['weak_random', 'http_urls', 'debug_enabled']
        
        if vuln_name in critical:
            return 'critical'
        elif vuln_name in high:
            return 'high'
        elif vuln_name in medium:
            return 'medium'
        else:
            return 'low'
    
    def add_issue(self, issue: Dict, severity: str):
        """Add issue to appropriate severity category"""
        if severity == 'critical':
            self.results['critical_issues'].append(issue)
        elif severity == 'high':
            self.results['high_issues'].append(issue)
        elif severity == 'medium':
            self.results['medium_issues'].append(issue)
        else:
            self.results['low_issues'].append(issue)
    
    def calculate_security_score(self):
        """Calculate overall security score"""
        # Start with perfect score
        score = 100
        
        # Deduct points based on issues
        score -= len(self.results['critical_issues']) * 20
        score -= len(self.results['high_issues']) * 10
        score -= len(self.results['medium_issues']) * 5
        score -= len(self.results['low_issues']) * 2
        
        # Ensure score doesn't go below 0
        score = max(0, score)
        
        # Add statistics
        self.results['statistics'] = {
            'total_issues': sum([
                len(self.results['critical_issues']),
                len(self.results['high_issues']),
                len(self.results['medium_issues']),
                len(self.results['low_issues'])
            ]),
            'critical_count': len(self.results['critical_issues']),
            'high_count': len(self.results['high_issues']),
            'medium_count': len(self.results['medium_issues']),
            'low_count': len(self.results['low_issues']),
            'files_scanned': len(list(self.project_path.rglob('*.swift')))
        }
        
        self.results['security_score'] = score
    
    def export_results(self, output_path: str):
        """Export results to JSON and Markdown"""
        # Export JSON
        json_path = Path(output_path) / 'security_analysis.json'
        with open(json_path, 'w') as f:
            json.dump(self.results, f, indent=2, default=str)
        
        # Export Markdown report
        md_path = Path(output_path) / 'SECURITY_ANALYSIS_REPORT.md'
        with open(md_path, 'w') as f:
            f.write(self.generate_markdown_report())
        
        print(f"\n📊 Results exported to:")
        print(f"  - {json_path}")
        print(f"  - {md_path}")
    
    def generate_markdown_report(self) -> str:
        """Generate markdown report"""
        report = f"""# Security Analysis Report

**Generated**: {self.results['timestamp']}
**Security Score**: {self.results['security_score']}/100

## Executive Summary

- **Total Issues Found**: {self.results['statistics']['total_issues']}
- **Critical Issues**: {self.results['statistics']['critical_count']}
- **High Issues**: {self.results['statistics']['high_count']}
- **Medium Issues**: {self.results['statistics']['medium_count']}
- **Low Issues**: {self.results['statistics']['low_count']}
- **Files Scanned**: {self.results['statistics']['files_scanned']}

## Critical Issues
"""
        
        if self.results['critical_issues']:
            for issue in self.results['critical_issues']:
                report += f"\n### {issue.get('type', 'Issue')}\n"
                for key, value in issue.items():
                    if key != 'type':
                        report += f"- **{key.replace('_', ' ').title()}**: {value}\n"
        else:
            report += "\n✅ No critical issues found\n"
        
        report += "\n## High Priority Issues\n"
        if self.results['high_issues']:
            for issue in self.results['high_issues'][:10]:  # Limit to first 10
                report += f"\n### {issue.get('type', 'Issue')}\n"
                for key, value in issue.items():
                    if key != 'type':
                        report += f"- **{key.replace('_', ' ').title()}**: {value}\n"
        else:
            report += "\n✅ No high priority issues found\n"
        
        report += "\n## Best Practices\n"
        for practice in self.results['best_practices']:
            report += f"- {practice}\n"
        
        report += "\n## Recommendations\n\n"
        report += """
1. **Immediate Actions**:
   - Address all critical security issues immediately
   - Review and fix hardcoded credentials
   - Implement SSL/TLS certificate pinning
   
2. **Short Term**:
   - Update all dependencies to latest secure versions
   - Implement comprehensive input validation
   - Add security-focused linting rules
   
3. **Long Term**:
   - Establish security review process
   - Implement automated security scanning in CI/CD
   - Create and maintain SECURITY.md documentation
   - Regular security audits and penetration testing
"""
        
        return report


def main():
    # Get project root
    project_path = Path.cwd()
    
    # Create analyzer
    analyzer = SecurityAnalyzer(project_path)
    
    # Run analysis
    results = analyzer.analyze()
    
    # Export results
    analyzer.export_results(project_path)
    
    # Print summary
    print(f"\n{'='*50}")
    print(f"Security Analysis Complete!")
    print(f"{'='*50}")
    print(f"Security Score: {results['security_score']}/100")
    print(f"Total Issues: {results['statistics']['total_issues']}")
    print(f"  - Critical: {results['statistics']['critical_count']}")
    print(f"  - High: {results['statistics']['high_count']}")
    print(f"  - Medium: {results['statistics']['medium_count']}")
    print(f"  - Low: {results['statistics']['low_count']}")


if __name__ == "__main__":
    main()
