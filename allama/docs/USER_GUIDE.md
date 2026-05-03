# Allama 用户开发与应用文档手册

## 目录

1. [快速开始](#快速开始)
2. [安装指南](#安装指南)
3. [认证系统应用案例](#认证系统应用案例)
4. [计费系统应用案例](#计费系统应用案例)
5. [OpenAI兼容API应用案例](#openai兼容api应用案例)
6. [高级功能应用案例](#高级功能应用案例)
7. [故障排除](#故障排除)
8. [常见问题FAQ](#常见问题faq)

---

## 快速开始

### 5分钟快速体验

Allama是一个航空级安全的LLM推理服务器，支持用户认证、计费和OpenAI兼容API。

**步骤1：启动服务器**

```bash
# 编译项目（如果还没有编译）
cargo build --release

# 启动服务器
./target/release/allama serve --port 11435
```

服务器启动后会自动创建默认测试用户并显示API Key：

```
==========================================
Default Test User Created
==========================================
Username: test_user
API Key: allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm
Rate Limit: 60 requests/minute
Monthly Quota: 100000 tokens
==========================================
```

**步骤2：本地测试（无需认证）**

```bash
curl -X POST http://localhost:11435/api/generate \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -d '{"model":"llama3","prompt":"Hello, world!","stream":false}'
```

**步骤3：远程测试（使用认证）**

```bash
curl -X POST http://localhost:11435/api/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm" \
  -H "X-Forwarded-For: 192.168.1.100" \
  -d '{"model":"llama3","prompt":"Hello, world!","stream":false}'
```

**步骤4：查看使用统计**

```bash
curl -X GET "http://localhost:11435/api/billing/records?limit=5" \
  -H "Authorization: Bearer allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm" \
  -H "X-Forwarded-For: 127.0.0.1"
```

---

## 安装指南

### 系统要求

- **操作系统**：Windows 10+、macOS 10.15+、主流Linux发行版
- **Rust**：1.70或更高版本（从源码编译）
- **内存**：至少8GB RAM
- **存储**：至少10GB可用空间
- **GPU**（可选）：NVIDIA CUDA、Apple Silicon Metal、AMD ROCm

### 从源码编译

```bash
# 克隆仓库
git clone https://github.com/arkCyber/allama.git
cd allama

# 编译
cargo build --release

# 二进制文件位置
./target/release/allama
```

### 验证安装

```bash
# 检查版本
./target/release/allama --version

# 查看帮助
./target/release/allama --help
```

---

## 认证系统应用案例

### 案例1：创建企业用户账号

**场景**：企业需要为不同部门创建独立的API访问账号，每个部门有不同的配额限制。

**实现步骤：**

```bash
# 创建研发部门账号
curl -X POST http://localhost:11435/api/users \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -d '{
    "username": "rd_team",
    "email": "rd@company.com",
    "rate_limit": 120,
    "monthly_quota": 5000000
  }'

# 创建市场部门账号
curl -X POST http://localhost:11435/api/users \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -d '{
    "username": "marketing_team",
    "email": "marketing@company.com",
    "rate_limit": 60,
    "monthly_quota": 1000000
  }'
```

**响应示例：**

```json
{
  "user_id": "user_abc123",
  "username": "rd_team",
  "email": "rd@company.com",
  "api_key": "allama_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "rate_limit": 120,
  "monthly_quota": 5000000,
  "created_at": "2026-05-03T08:00:00Z"
}
```

### 案例2：Python应用集成认证

**场景**：Python后端应用需要使用Allama API进行文本生成，需要集成认证机制。

**实现代码：**

```python
import requests
import os

class AllamaClient:
    def __init__(self, base_url="http://localhost:11435", api_key=None):
        self.base_url = base_url
        self.api_key = api_key or os.getenv("ALLAMA_API_KEY")
        
    def generate(self, model, prompt, stream=False):
        """生成文本"""
        url = f"{self.base_url}/api/generate"
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}",
            "X-Forwarded-For": "192.168.1.100"
        }
        data = {
            "model": model,
            "prompt": prompt,
            "stream": stream
        }
        response = requests.post(url, headers=headers, json=data)
        return response.json()
    
    def chat(self, model, messages, stream=False):
        """对话生成"""
        url = f"{self.base_url}/api/chat"
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}",
            "X-Forwarded-For": "192.168.1.100"
        }
        data = {
            "model": model,
            "messages": messages,
            "stream": stream
        }
        response = requests.post(url, headers=headers, json=data)
        return response.json()

# 使用示例
if __name__ == "__main__":
    # 设置API Key（从环境变量或直接设置）
    client = AllamaClient(api_key="allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm")
    
    # 生成文本
    result = client.generate("llama3", "Write a short poem about AI")
    print(f"Generated: {result['response']}")
    
    # 对话
    messages = [
        {"role": "user", "content": "What is the capital of France?"}
    ]
    result = client.chat("llama3", messages)
    print(f"Chat response: {result['message']['content']}")
```

### 案例3：Node.js应用集成认证

**场景**：Node.js Web应用需要调用Allama API进行内容生成。

**实现代码：**

```javascript
const axios = require('axios');

class AllamaClient {
    constructor(baseUrl = 'http://localhost:11435', apiKey = null) {
        this.baseUrl = baseUrl;
        this.apiKey = apiKey || process.env.ALLAMA_API_KEY;
    }

    async generate(model, prompt, stream = false) {
        const url = `${this.baseUrl}/api/generate`;
        const headers = {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${this.apiKey}`,
            'X-Forwarded-For': '192.168.1.100'
        };
        const data = {
            model,
            prompt,
            stream
        };
        const response = await axios.post(url, data, { headers });
        return response.data;
    }

    async chat(model, messages, stream = false) {
        const url = `${this.baseUrl}/api/chat`;
        const headers = {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${this.apiKey}`,
            'X-Forwarded-For': '192.168.1.100'
        };
        const data = {
            model,
            messages,
            stream
        };
        const response = await axios.post(url, data, { headers });
        return response.data;
    }
}

// 使用示例
async function main() {
    const client = new AllamaClient('http://localhost:11435', 'allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm');
    
    // 生成文本
    const genResult = await client.generate('llama3', 'Write a short story');
    console.log('Generated:', genResult.response);
    
    // 对话
    const messages = [
        { role: 'user', content: 'Explain quantum computing' }
    ];
    const chatResult = await client.chat('llama3', messages);
    console.log('Chat response:', chatResult.message.content);
}

main().catch(console.error);
```

### 案例4：多租户SaaS应用认证

**场景**：SaaS平台需要为每个租户提供独立的API Key和配额管理。

**实现架构：**

```python
import requests
import json
from typing import Dict, Optional

class TenantManager:
    def __init__(self, allama_base_url="http://localhost:11435"):
        self.base_url = allama_base_url
        self.tenants: Dict[str, dict] = {}
    
    def create_tenant(self, tenant_id: str, email: str, rate_limit: int, monthly_quota: int) -> dict:
        """为租户创建用户账号"""
        url = f"{self.base_url}/api/users"
        headers = {
            "Content-Type": "application/json",
            "X-Forwarded-For": "127.0.0.1"
        }
        data = {
            "username": f"tenant_{tenant_id}",
            "email": email,
            "rate_limit": rate_limit,
            "monthly_quota": monthly_quota
        }
        
        response = requests.post(url, headers=headers, json=data)
        user_data = response.json()
        
        self.tenants[tenant_id] = {
            "user_id": user_data["user_id"],
            "api_key": user_data["api_key"],
            "rate_limit": rate_limit,
            "monthly_quota": monthly_quota
        }
        
        return self.tenants[tenant_id]
    
    def get_tenant_api_key(self, tenant_id: str) -> Optional[str]:
        """获取租户的API Key"""
        if tenant_id in self.tenants:
            return self.tenants[tenant_id]["api_key"]
        return None
    
    def get_tenant_usage(self, tenant_id: str) -> dict:
        """获取租户使用情况"""
        api_key = self.get_tenant_api_key(tenant_id)
        if not api_key:
            return {"error": "Tenant not found"}
        
        url = f"{self.base_url}/api/billing/summary"
        headers = {
            "Authorization": f"Bearer {api_key}",
            "X-Forwarded-For": "127.0.0.1"
        }
        
        response = requests.get(url, headers=headers)
        return response.json()

# 使用示例
manager = TenantManager()

# 创建租户
tenant1 = manager.create_tenant(
    tenant_id="acme_corp",
    email="tech@acme.com",
    rate_limit=100,
    monthly_quota=2000000
)

print(f"Created tenant: {tenant1}")

# 获取使用情况
usage = manager.get_tenant_usage("acme_corp")
print(f"Tenant usage: {usage}")
```

---

## 计费系统应用案例

### 案例5：实时监控API使用量

**场景**：需要实时监控API调用情况和token使用量，用于成本控制和告警。

**实现代码：**

```python
import requests
import time
from datetime import datetime, timedelta
from typing import List, Dict

class UsageMonitor:
    def __init__(self, base_url="http://localhost:11435", api_key=None):
        self.base_url = base_url
        self.api_key = api_key
        self.alert_threshold = 0.8  # 80%配额使用时告警
    
    def get_usage_records(self, limit=100) -> List[Dict]:
        """获取使用记录"""
        url = f"{self.base_url}/api/billing/records"
        params = {"limit": limit}
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "X-Forwarded-For": "127.0.0.1"
        }
        
        response = requests.get(url, params=params, headers=headers)
        data = response.json()
        return data.get("records", [])
    
    def get_usage_summary(self) -> Dict:
        """获取使用摘要"""
        url = f"{self.base_url}/api/billing/summary"
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "X-Forwarded-For": "127.0.0.1"
        }
        
        response = requests.get(url, headers=headers)
        return response.json()
    
    def check_quota_alert(self) -> bool:
        """检查是否需要告警"""
        summary = self.get_usage_summary()
        
        if "monthly_quota" in summary and "total_tokens" in summary:
            quota = summary["monthly_quota"]
            used = summary["total_tokens"]
            
            if quota > 0:
                usage_ratio = used / quota
                if usage_ratio >= self.alert_threshold:
                    print(f"⚠️  警告：已使用 {usage_ratio:.1%} 的月度配额 ({used}/{quota} tokens)")
                    return True
        
        return False
    
    def monitor_continuously(self, interval=60):
        """持续监控"""
        print(f"开始监控API使用情况（每{interval}秒检查一次）...")
        print("按Ctrl+C停止监控")
        
        try:
            while True:
                summary = self.get_usage_summary()
                
                print(f"\n[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}]")
                print(f"总Token数: {summary.get('total_tokens', 0)}")
                print(f"总请求数: {summary.get('total_requests', 0)}")
                print(f"月度配额: {summary.get('monthly_quota', 0)}")
                
                self.check_quota_alert()
                
                time.sleep(interval)
        except KeyboardInterrupt:
            print("\n监控已停止")

# 使用示例
if __name__ == "__main__":
    monitor = UsageMonitor(
        base_url="http://localhost:11435",
        api_key="allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm"
    )
    
    # 单次检查
    summary = monitor.get_usage_summary()
    print(f"使用摘要: {summary}")
    
    # 持续监控
    # monitor.monitor_continuously(interval=30)
```

### 案例6：按部门统计使用情况

**场景**：企业需要按部门统计API使用情况，用于成本分摊和资源规划。

**实现代码：**

```python
import requests
from typing import Dict, List
from datetime import datetime, timedelta

class DepartmentUsageReporter:
    def __init__(self, base_url="http://localhost:11435"):
        self.base_url = base_url
        self.departments = {
            "rd": "allama_rd_team_key",
            "marketing": "allama_marketing_team_key",
            "support": "allama_support_team_key"
        }
    
    def get_department_usage(self, dept_name: str, days=30) -> Dict:
        """获取指定部门的使用情况"""
        if dept_name not in self.departments:
            return {"error": f"Department {dept_name} not found"}
        
        api_key = self.departments[dept_name]
        
        # 获取最近N天的记录
        start_date = datetime.now() - timedelta(days=days)
        url = f"{self.base_url}/api/billing/records"
        params = {
            "start_date": start_date.isoformat(),
            "limit": 1000
        }
        headers = {
            "Authorization": f"Bearer {api_key}",
            "X-Forwarded-For": "127.0.0.1"
        }
        
        response = requests.get(url, params=params, headers=headers)
        records = response.json().get("records", [])
        
        # 统计
        total_tokens = sum(r["total_tokens"] for r in records)
        total_requests = len(records)
        model_usage = {}
        
        for record in records:
            model = record["model_name"]
            model_usage[model] = model_usage.get(model, 0) + record["total_tokens"]
        
        return {
            "department": dept_name,
            "period_days": days,
            "total_tokens": total_tokens,
            "total_requests": total_requests,
            "model_usage": model_usage,
            "avg_tokens_per_request": total_tokens / total_requests if total_requests > 0 else 0
        }
    
    def generate_report(self) -> Dict:
        """生成所有部门的使用报告"""
        report = {
            "generated_at": datetime.now().isoformat(),
            "departments": {}
        }
        
        for dept_name in self.departments.keys():
            usage = self.get_department_usage(dept_name)
            report["departments"][dept_name] = usage
        
        return report
    
    def print_report(self):
        """打印报告"""
        report = self.generate_report()
        
        print("=" * 60)
        print("部门API使用报告")
        print("=" * 60)
        print(f"生成时间: {report['generated_at']}")
        print()
        
        for dept_name, usage in report["departments"].items():
            print(f"部门: {dept_name.upper()}")
            print(f"  总Token数: {usage['total_tokens']:,}")
            print(f"  总请求数: {usage['total_requests']:,}")
            print(f"  平均每请求: {usage['avg_tokens_per_request']:.1f} tokens")
            print(f"  模型使用:")
            for model, tokens in usage.get('model_usage', {}).items():
                print(f"    - {model}: {tokens:,} tokens")
            print()

# 使用示例
if __name__ == "__main__":
    reporter = DepartmentUsageReporter()
    reporter.print_report()
```

### 案例7：成本预测和预算管理

**场景**：根据历史使用数据预测未来成本，帮助制定预算。

**实现代码：**

```python
import requests
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Tuple

class CostPredictor:
    def __init__(self, base_url="http://localhost:11435", api_key=None, cost_per_1k_tokens=0.001):
        self.base_url = base_url
        self.api_key = api_key
        self.cost_per_1k_tokens = cost_per_1k_tokens
    
    def get_historical_usage(self, days=30) -> List[Dict]:
        """获取历史使用数据"""
        start_date = datetime.now() - timedelta(days=days)
        url = f"{self.base_url}/api/billing/records"
        params = {
            "start_date": start_date.isoformat(),
            "limit": 10000
        }
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "X-Forwarded-For": "127.0.0.1"
        }
        
        response = requests.get(url, params=params, headers=headers)
        return response.json().get("records", [])
    
    def calculate_daily_usage(self, records: List[Dict]) -> Dict[str, int]:
        """计算每日使用量"""
        daily_usage = {}
        
        for record in records:
            date = record["timestamp"][:10]  # YYYY-MM-DD
            daily_usage[date] = daily_usage.get(date, 0) + record["total_tokens"]
        
        return daily_usage
    
    def predict_monthly_usage(self, days=30) -> Dict:
        """预测月度使用量"""
        records = self.get_historical_usage(days)
        daily_usage = self.calculate_daily_usage(records)
        
        if not daily_usage:
            return {"error": "No usage data available"}
        
        # 计算平均每日使用量
        avg_daily = np.mean(list(daily_usage.values()))
        
        # 计算标准差（用于估算波动范围）
        std_daily = np.std(list(daily_usage.values()))
        
        # 预测30天使用量
        predicted_monthly = avg_daily * 30
        predicted_range = (
            (avg_daily - std_daily) * 30,
            (avg_daily + std_daily) * 30
        )
        
        # 计算成本
        predicted_cost = predicted_monthly / 1000 * self.cost_per_1k_tokens
        cost_range = (
            predicted_range[0] / 1000 * self.cost_per_1k_tokens,
            predicted_range[1] / 1000 * self.cost_per_1k_tokens
        )
        
        return {
            "historical_days": len(daily_usage),
            "avg_daily_tokens": round(avg_daily),
            "std_daily_tokens": round(std_daily),
            "predicted_monthly_tokens": round(predicted_monthly),
            "predicted_monthly_range": (round(predicted_range[0]), round(predicted_range[1])),
            "predicted_monthly_cost": round(predicted_cost, 2),
            "predicted_cost_range": (round(cost_range[0], 2), round(cost_range[1], 2)),
            "cost_per_1k_tokens": self.cost_per_1k_tokens
        }
    
    def print_prediction(self):
        """打印预测报告"""
        prediction = self.predict_monthly_usage()
        
        print("=" * 60)
        print("成本预测报告")
        print("=" * 60)
        print(f"历史数据天数: {prediction['historical_days']}")
        print(f"平均每日Token: {prediction['avg_daily_tokens']:,}")
        print(f"标准差: {prediction['std_daily_tokens']:,}")
        print()
        print(f"预测月度Token: {prediction['predicted_monthly_tokens']:,}")
        print(f"预测范围: {prediction['predicted_monthly_range'][0]:,} - {prediction['predicted_monthly_range'][1]:,}")
        print()
        print(f"预测月度成本: ${prediction['predicted_monthly_cost']:.2f}")
        print(f"成本范围: ${prediction['predicted_cost_range'][0]:.2f} - ${prediction['predicted_cost_range'][1]:.2f}")
        print(f"Token价格: ${prediction['cost_per_1k_tokens']:.4f}/1k tokens")
        print("=" * 60)

# 使用示例
if __name__ == "__main__":
    predictor = CostPredictor(
        base_url="http://localhost:11435",
        api_key="allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm",
        cost_per_1k_tokens=0.001
    )
    
    predictor.print_prediction()
```

---

## OpenAI兼容API应用案例

### 案例8：使用OpenAI Python SDK

**场景**：现有使用OpenAI SDK的应用可以无缝切换到Allama，无需修改代码。

**实现代码：**

```python
from openai import OpenAI

# 配置Allama作为OpenAI兼容端点
client = OpenAI(
    base_url="http://localhost:11435/v1",
    api_key="allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm"
)

# Chat Completions
response = client.chat.completions.create(
    model="llama3",
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Explain quantum computing in simple terms."}
    ],
    temperature=0.7,
    max_tokens=500
)

print(f"Response: {response.choices[0].message.content}")

# Completions
response = client.completions.create(
    model="llama3",
    prompt="Write a haiku about programming",
    max_tokens=100
)

print(f"Completion: {response.choices[0].text}")

# Embeddings
response = client.embeddings.create(
    model="llama3",
    input="Hello, world!"
)

print(f"Embedding dimension: {len(response.data[0].embedding)}")
```

### 案例9：使用OpenAI Node.js SDK

**场景**：Node.js应用使用OpenAI SDK连接Allama。

**实现代码：**

```javascript
const OpenAI = require('openai');

// 配置Allama作为OpenAI兼容端点
const openai = new OpenAI({
  baseURL: 'http://localhost:11435/v1',
  apiKey: 'allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm'
});

async function main() {
  // Chat Completions
  const chatResponse = await openai.chat.completions.create({
    model: 'llama3',
    messages: [
      { role: 'system', content: 'You are a helpful assistant.' },
      { role: 'user', content: 'What is machine learning?' }
    ],
    temperature: 0.7,
    max_tokens: 500
  });

  console.log('Chat response:', chatResponse.choices[0].message.content);

  // Completions
  const completionResponse = await openai.completions.create({
    model: 'llama3',
    prompt: 'Write a short story about AI',
    max_tokens: 300
  });

  console.log('Completion:', completionResponse.choices[0].text);

  // Embeddings
  const embeddingResponse = await openai.embeddings.create({
    model: 'llama3',
    input: 'Hello, world!'
  });

  console.log('Embedding dimension:', embeddingResponse.data[0].embedding.length);
}

main().catch(console.error);
```

### 案例10：LangChain集成

**场景**：使用LangChain框架构建RAG应用，后端使用Allama。

**实现代码：**

```python
from langchain.llms import OpenAI
from langchain.chat_models import ChatOpenAI
from langchain.embeddings import OpenAIEmbeddings
from langchain.chains import ConversationalRetrievalChain
from langchain.vectorstores import FAISS
from langchain.text_splitter import CharacterTextSplitter
from langchain.document_loaders import TextLoader

# 配置Allama作为OpenAI兼容端点
llm = OpenAI(
    openai_api_base="http://localhost:11435/v1",
    openai_api_key="allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm",
    model_name="llama3",
    temperature=0.7
)

chat = ChatOpenAI(
    openai_api_base="http://localhost:11435/v1",
    openai_api_key="allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm",
    model="llama3"
)

embeddings = OpenAIEmbeddings(
    openai_api_base="http://localhost:11435/v1",
    openai_api_key="allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm"
)

# 使用示例
def simple_qa():
    """简单问答"""
    response = llm("What is the capital of France?")
    print(f"Answer: {response}")

def build_rag_system():
    """构建RAG系统"""
    # 加载文档
    loader = TextLoader("documents/sample.txt")
    documents = loader.load()
    
    # 分割文档
    text_splitter = CharacterTextSplitter(chunk_size=1000, chunk_overlap=0)
    texts = text_splitter.split_documents(documents)
    
    # 创建向量存储
    vectorstore = FAISS.from_documents(texts, embeddings)
    
    # 创建检索链
    retriever = vectorstore.as_retriever()
    qa_chain = ConversationalRetrievalChain.from_llm(
        llm=chat,
        retriever=retriever
    )
    
    # 问答
    query = "What is the main topic of the document?"
    result = qa_chain({"question": query, "chat_history": []})
    print(f"Answer: {result['answer']}")

if __name__ == "__main__":
    simple_qa()
    # build_rag_system()
```

---

## 高级功能应用案例

### 案例11：流式响应处理

**场景**：实时显示生成的文本，提供更好的用户体验。

**实现代码：**

```python
import requests
import json

def stream_generate(model, prompt, api_key):
    """流式生成文本"""
    url = "http://localhost:11435/api/generate"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}",
        "X-Forwarded-For": "192.168.1.100"
    }
    data = {
        "model": model,
        "prompt": prompt,
        "stream": True
    }
    
    response = requests.post(url, headers=headers, json=data, stream=True)
    
    print("流式生成开始:")
    for line in response.iter_lines():
        if line:
            try:
                chunk = json.loads(line.decode('utf-8'))
                if 'response' in chunk:
                    print(chunk['response'], end='', flush=True)
                if chunk.get('done', False):
                    print("\n生成完成")
                    break
            except json.JSONDecodeError:
                continue

# 使用示例
if __name__ == "__main__":
    stream_generate(
        model="llama3",
        prompt="Write a short story about a robot learning to love",
        api_key="allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm"
    )
```

### 案例12：批量处理与并发控制

**场景**：需要处理大量请求，同时控制并发数以避免超限。

**实现代码：**

```python
import requests
import asyncio
import aiohttp
from typing import List
from concurrent.futures import ThreadPoolExecutor, as_completed

class BatchProcessor:
    def __init__(self, base_url="http://localhost:11435", api_key=None, max_concurrent=10):
        self.base_url = base_url
        self.api_key = api_key
        self.max_concurrent = max_concurrent
        self.semaphore = asyncio.Semaphore(max_concurrent)
    
    async def async_generate(self, session, model, prompt):
        """异步生成"""
        async with self.semaphore:
            url = f"{self.base_url}/api/generate"
            headers = {
                "Content-Type": "application/json",
                "Authorization": f"Bearer {self.api_key}",
                "X-Forwarded-For": "192.168.1.100"
            }
            data = {
                "model": model,
                "prompt": prompt,
                "stream": False
            }
            
            async with session.post(url, headers=headers, json=data) as response:
                return await response.json()
    
    async def process_batch_async(self, prompts: List[str], model="llama3"):
        """异步批量处理"""
        async with aiohttp.ClientSession() as session:
            tasks = [
                self.async_generate(session, model, prompt)
                for prompt in prompts
            ]
            results = await asyncio.gather(*tasks, return_exceptions=True)
            
            successful = [r for r in results if not isinstance(r, Exception)]
            failed = [r for r in results if isinstance(r, Exception)]
            
            return {
                "total": len(prompts),
                "successful": len(successful),
                "failed": len(failed),
                "results": successful
            }
    
    def process_batch_sync(self, prompts: List[str], model="llama3"):
        """同步批量处理（使用线程池）"""
        url = f"{self.base_url}/api/generate"
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}",
            "X-Forwarded-For": "192.168.1.100"
        }
        
        results = []
        with ThreadPoolExecutor(max_workers=self.max_concurrent) as executor:
            futures = {
                executor.submit(
                    requests.post,
                    url,
                    headers=headers,
                    json={"model": model, "prompt": prompt, "stream": False}
                ): prompt
                for prompt in prompts
            }
            
            for future in as_completed(futures):
                try:
                    response = future.result()
                    results.append(response.json())
                except Exception as e:
                    print(f"Error processing prompt: {e}")
        
        return results

# 使用示例
if __name__ == "__main__":
    processor = BatchProcessor(
        base_url="http://localhost:11435",
        api_key="allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm",
        max_concurrent=5
    )
    
    # 准备批量提示
    prompts = [
        "What is AI?",
        "Explain machine learning",
        "What is deep learning?",
        "Define neural networks",
        "What is natural language processing?"
    ]
    
    # 异步处理
    async def main_async():
        result = await processor.process_batch_async(prompts)
        print(f"异步处理结果: {result}")
    
    asyncio.run(main_async())
    
    # 同步处理
    # results = processor.process_batch_sync(prompts)
    # print(f"同步处理结果数: {len(results)}")
```

### 案例13：错误处理和重试机制

**场景**：网络不稳定时需要自动重试，确保请求成功。

**实现代码：**

```python
import requests
import time
from typing import Optional, Callable
from functools import wraps

class AllamaAPIError(Exception):
    """Allama API错误"""
    pass

def retry_on_error(max_retries=3, delay=1, backoff=2):
    """重试装饰器"""
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            last_exception = None
            current_delay = delay
            
            for attempt in range(max_retries):
                try:
                    return func(*args, **kwargs)
                except requests.exceptions.RequestException as e:
                    last_exception = e
                    if attempt < max_retries - 1:
                        print(f"请求失败，{current_delay}秒后重试... (尝试 {attempt + 1}/{max_retries})")
                        time.sleep(current_delay)
                        current_delay *= backoff
                    else:
                        raise AllamaAPIError(f"重试{max_retries}次后仍然失败: {e}")
                except Exception as e:
                    raise AllamaAPIError(f"请求出错: {e}")
            
            raise last_exception
        return wrapper
    return decorator

class RobustAllamaClient:
    def __init__(self, base_url="http://localhost:11435", api_key=None):
        self.base_url = base_url
        self.api_key = api_key
    
    @retry_on_error(max_retries=3, delay=1, backoff=2)
    def generate(self, model, prompt, stream=False, timeout=30):
        """带重试的文本生成"""
        url = f"{self.base_url}/api/generate"
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}",
            "X-Forwarded-For": "192.168.1.100"
        }
        data = {
            "model": model,
            "prompt": prompt,
            "stream": stream
        }
        
        response = requests.post(url, headers=headers, json=data, timeout=timeout)
        
        if response.status_code == 401:
            raise AllamaAPIError("认证失败：无效的API Key")
        elif response.status_code == 429:
            raise AllamaAPIError("速率限制：请求过于频繁")
        elif response.status_code >= 500:
            raise AllamaAPIError(f"服务器错误: {response.status_code}")
        
        response.raise_for_status()
        return response.json()
    
    @retry_on_error(max_retries=3, delay=1, backoff=2)
    def chat(self, model, messages, stream=False, timeout=30):
        """带重试的对话生成"""
        url = f"{self.base_url}/api/chat"
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}",
            "X-Forwarded-For": "192.168.1.100"
        }
        data = {
            "model": model,
            "messages": messages,
            "stream": stream
        }
        
        response = requests.post(url, headers=headers, json=data, timeout=timeout)
        
        if response.status_code == 401:
            raise AllamaAPIError("认证失败：无效的API Key")
        elif response.status_code == 429:
            raise AllamaAPIError("速率限制：请求过于频繁")
        elif response.status_code >= 500:
            raise AllamaAPIError(f"服务器错误: {response.status_code}")
        
        response.raise_for_status()
        return response.json()

# 使用示例
if __name__ == "__main__":
    client = RobustAllamaClient(
        base_url="http://localhost:11435",
        api_key="allama_Heaaq4pYRY2kmJl4wvGcZjceyTO9ifKm"
    )
    
    try:
        result = client.generate("llama3", "Write a haiku")
        print(f"生成结果: {result['response']}")
    except AllamaAPIError as e:
        print(f"API错误: {e}")
```

---

## 故障排除

### 常见问题

**1. 认证失败 (401 Unauthorized)**

**症状：**
```json
{"error":"Unauthorized"}
```

**可能原因：**
- API Key无效或已过期
- 请求头格式错误
- API Key被撤销

**解决方案：**
```bash
# 检查API Key是否正确
echo $ALLAMA_API_KEY

# 重新获取API Key
curl -X GET http://localhost:11435/api/users \
  -H "Authorization: Bearer your_admin_key" \
  -H "X-Forwarded-For: 127.0.0.1"

# 确保请求头格式正确
curl -X POST http://localhost:11435/api/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your_api_key" \
  -H "X-Forwarded-For: 192.168.1.100" \
  -d '{"model":"llama3","prompt":"test","stream":false}'
```

**2. 速率限制 (429 Too Many Requests)**

**症状：**
```json
{"error":"Rate limit exceeded"}
```

**可能原因：**
- 超过每分钟请求限制
- 并发请求过多

**解决方案：**
```python
import time
import requests

def rate_limited_request(url, headers, data, max_retries=3):
    """带速率限制的请求"""
    for attempt in range(max_retries):
        response = requests.post(url, headers=headers, json=data)
        
        if response.status_code == 429:
            wait_time = 2 ** attempt  # 指数退避
            print(f"速率限制，等待{wait_time}秒后重试...")
            time.sleep(wait_time)
        else:
            return response.json()
    
    raise Exception("超过最大重试次数")

# 使用示例
result = rate_limited_request(
    url="http://localhost:11435/api/generate",
    headers={
        "Content-Type": "application/json",
        "Authorization": "Bearer your_api_key",
        "X-Forwarded-For": "192.168.1.100"
    },
    data={"model":"llama3","prompt":"test","stream":false}
)
```

**3. 服务器无响应**

**症状：**
- 连接超时
- 无法连接到服务器

**可能原因：**
- 服务器未启动
- 端口被占用
- 防火墙阻止

**解决方案：**
```bash
# 检查服务器是否运行
ps aux | grep allama

# 检查端口是否被占用
lsof -i :11435

# 重启服务器
./target/release/allama serve --port 11435

# 检查防火墙
sudo ufw status
sudo ufw allow 11435
```

**4. 配额用尽**

**症状：**
```json
{"error":"Monthly quota exceeded"}
```

**解决方案：**
```bash
# 查看当前使用情况
curl -X GET http://localhost:11435/api/billing/summary \
  -H "Authorization: Bearer your_api_key" \
  -H "X-Forwarded-For: 127.0.0.1"

# 联系管理员增加配额
# 或等待下个月配额重置
```

### 调试技巧

**1. 启用详细日志**

```bash
# 设置RUST_LOG环境变量
RUST_LOG=debug ./target/release/allama serve --port 11435
```

**2. 检查审计日志**

```bash
# 查看审计日志
cat ~/.allama/data/audit/audit.log
```

**3. 测试连接**

```bash
# 测试基本连接
curl -v http://localhost:11435/api/tags

# 测试认证
curl -v -X POST http://localhost:11435/api/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your_api_key" \
  -H "X-Forwarded-For: 192.168.1.100" \
  -d '{"model":"llama3","prompt":"test","stream":false}'
```

---

## 常见问题FAQ

### Q1: 如何获取API Key？

**A:** 有两种方式获取API Key：

1. **使用默认测试账号**：服务器启动时会自动创建默认测试用户并显示API Key
2. **创建新用户**：通过API创建新用户并获取API Key

```bash
curl -X POST http://localhost:11435/api/users \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -d '{"username":"myuser","email":"user@example.com","rate_limit":60,"monthly_quota":1000000}'
```

### Q2: 本地请求需要认证吗？

**A:** 不需要。来自127.0.0.1、::1或localhost的请求会自动绕过认证。

```bash
# 本地请求（无需认证）
curl -X POST http://localhost:11435/api/generate \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 127.0.0.1" \
  -d '{"model":"llama3","prompt":"test","stream":false}'
```

### Q3: 如何在生产环境中部署？

**A:** 生产环境部署建议：

1. **使用HTTPS**：配置SSL证书
2. **创建专用用户**：不要使用默认测试账号
3. **设置合理的配额**：根据业务需求设置速率限制和月度配额
4. **监控使用情况**：定期检查计费记录
5. **定期备份**：备份认证数据库和计费数据库
6. **使用反向代理**：如Nginx，提供额外的安全层

### Q4: 如何与OpenAI SDK兼容？

**A:** Allama提供OpenAI兼容的API端点：

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:11435/v1",
    api_key="your_allama_api_key"
)

# 使用方式与OpenAI完全相同
response = client.chat.completions.create(...)
```

### Q5: 如何监控API使用情况？

**A:** 使用计费API监控使用情况：

```bash
# 获取使用摘要
curl -X GET http://localhost:11435/api/billing/summary \
  -H "Authorization: Bearer your_api_key" \
  -H "X-Forwarded-For: 127.0.0.1"

# 获取详细记录
curl -X GET "http://localhost:11435/api/billing/records?limit=100" \
  -H "Authorization: Bearer your_api_key" \
  -H "X-Forwarded-For: 127.0.0.1"
```

### Q6: 支持哪些模型？

**A:** Allama支持llama.cpp支持的所有模型，包括：
- LLaMA系列
- Mistral
- Qwen
- Gemma
- 等等

使用`/api/tags`端点查看可用模型：

```bash
curl http://localhost:11435/api/tags
```

### Q7: 如何提高请求吞吐量？

**A:** 提高吞吐量的方法：

1. **增加并行工作线程**：
```bash
./target/release/allama serve --parallel 8
```

2. **使用异步客户端**：参考案例12的批量处理
3. **优化模型选择**：使用更小的模型或量化版本
4. **使用流式响应**：减少延迟感知

### Q8: 数据存储在哪里？

**A:** 默认数据存储在`~/.allama/`目录：

```
~/.allama/
├── data/
│   ├── auth/
│   │   └── auth.db          # 认证数据库
│   ├── billing/
│   │   └── billing.db       # 计费数据库
│   └── audit/
│       └── audit.log        # 审计日志
```

### Q9: 如何备份和恢复数据？

**A:** 备份数据库文件：

```bash
# 备份
cp ~/.allama/data/auth/auth.db auth_backup.db
cp ~/.allama/data/billing/billing.db billing_backup.db

# 恢复
cp auth_backup.db ~/.allama/data/auth/auth.db
cp billing_backup.db ~/.allama/data/billing/billing.db
```

### Q10: 如何联系技术支持？

**A:** 
- GitHub Issues: https://github.com/arkCyber/allama/issues
- 文档: https://github.com/arkCyber/allama
- 认证指南: docs/AUTHENTICATION_GUIDE.md

---

## 附录

### A. API端点完整列表

详见README.md的API Endpoints章节。

### B. 环境变量

- `ALLAMA_BASE_URL`: Allama服务器地址
- `ALLAMA_API_KEY`: 默认API Key
- `ALLAMA_PORT`: 服务器端口
- `RUST_LOG`: 日志级别（debug, info, warn, error）

### C. 相关文档

- [认证系统指南](AUTHENTICATION_GUIDE.md)
- [README](../README.md)
- [llama.cpp文档](https://github.com/ggerganov/llama.cpp)

---

**文档版本**: 1.0  
**最后更新**: 2026-05-03  
**维护者**: Allama开发团队
