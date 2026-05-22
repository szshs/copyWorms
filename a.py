# 完整版 Python 运行环境检测
try:
    # 基础输出测试
    print("1. 基础打印功能：正常")
    
    # 数学运算测试
    a = 10
    b = 20
    print(f"2. 数学运算：10 + 20 = {a + b}")
    
    # 模块导入测试
    import math
    print(f"3. 模块导入：math.sqrt(16) = {math.sqrt(16)}")
    
    # 循环逻辑测试
    print("4. 循环功能：正常")
    for i in range(3):
        print(f"   循环第 {i+1} 次")
    
    print("\n✅ 【最终结果】你的 IDE 支持完整 Python 运行！")

except Exception as e:
    print("❌ 运行失败，错误信息：")
    print(e)