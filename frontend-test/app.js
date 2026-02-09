// 全局变量用于存储Supabase客户端实例
let supabaseClient = null;

// 初始化Supabase客户端函数
function initializeSupabase() {
    // 从全局配置获取Supabase配置
    const SUPABASE_URL = window.SUPABASE_CONFIG?.supabaseUrl;
    const SUPABASE_ANON_KEY = window.SUPABASE_CONFIG?.supabaseAnonKey;

    // 检查配置是否存在
    if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
        console.warn('Supabase配置未正确加载');
        return false;
    }

    try {
        // 初始化Supabase客户端
        supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
        console.log('Supabase客户端初始化成功');
        return true;
    } catch (error) {
        console.error('Supabase客户端初始化失败:', error);
        return false;
    }
}

// 确保Supabase客户端可用
function ensureSupabaseClient() {
    if (!supabaseClient) {
        const initialized = initializeSupabase();
        if (!initialized) {
            throw new Error('Supabase客户端未正确初始化，请检查配置');
        }
    }
    return supabaseClient;
}

// 切换标签页
function switchTab(tabName) {
    // 隐藏所有标签内容
    document.querySelectorAll('.tab-content').forEach(tab => {
        tab.classList.remove('active');
    });

    // 移除所有标签的激活状态
    document.querySelectorAll('.tab').forEach(tab => {
        tab.classList.remove('active');
    });

    // 显示选中的标签内容
    document.getElementById(`${tabName}-tab`).classList.add('active');

    // 激活选中的标签
    event.target.classList.add('active');
}

// 显示消息
function showMessage(elementId, message, type) {
    const messageElement = document.getElementById(elementId);
    messageElement.textContent = message;
    messageElement.className = `message ${type}`;
    messageElement.classList.remove('hidden');
}

// 隐藏消息
function hideMessage(elementId) {
    const messageElement = document.getElementById(elementId);
    messageElement.classList.add('hidden');
}

// 注册手机号
async function signUpWithPhone() {
    const phone = document.getElementById('register-phone').value;
    const button = document.getElementById('register-btn');

    if (!phone) {
        showMessage('register-message', '请输入手机号', 'error');
        return;
    }

    try {
        // 确保Supabase客户端可用
        const supabase = ensureSupabaseClient();

        // 禁用按钮并显示加载状态
        button.disabled = true;
        button.textContent = '发送中...';

         // 生成随机密码
        const randomPassword = Math.random().toString(36).slice(-8);

        // 使用signUp接口注册用户（通过手机号）
        const { data, error } = await supabase.auth.signUp({
            phone: phone,
            password: randomPassword
        });

        if (error) {
            showMessage('register-message', `注册失败: ${error.message}`, 'error');
        } else {
            showMessage('register-message', '验证码已发送，请查收短信', 'success');
            // 将手机号保存到验证页面
            document.getElementById('phone-number').value = phone;
            // 自动切换到验证标签页
            switchTab('verify');
        }
    } catch (error) {
        showMessage('register-message', `注册失败: ${error.message}`, 'error');
    } finally {
        // 恢复按钮状态
        if (button) {
            button.disabled = false;
            button.textContent = '发送验证码';
        }
    }
}

// 登录手机号
async function signInWithPhone() {
    const phone = document.getElementById('login-phone').value;
    const button = document.getElementById('login-btn');

    if (!phone) {
        showMessage('login-message', '请输入手机号', 'error');
        return;
    }

    try {
        // 确保Supabase客户端可用
        const supabase = ensureSupabaseClient();

        // 禁用按钮并显示加载状态
        button.disabled = true;
        button.textContent = '发送中...';

        // 发送验证码
        const { data, error } = await supabase.auth.signInWithOtp({
            phone: phone,
            options: {
                shouldCreateUser: false // 如果用户不存在则不创建
            }
        });

        if (error) {
            showMessage('login-message', `登录失败: ${error.message}`, 'error');
        } else {
            showMessage('login-message', '验证码已发送，请查收短信', 'success');
            // 将手机号保存到验证页面
            document.getElementById('phone-number').value = phone;
            // 自动切换到验证标签页
            switchTab('verify');
        }
    } catch (error) {
        showMessage('login-message', `登录失败: ${error.message}`, 'error');
    } finally {
        // 恢复按钮状态
        if (button) {
            button.disabled = false;
            button.textContent = '发送验证码';
        }
    }
}

// 验证OTP
async function verifyOTP() {
    const phone = document.getElementById('phone-number').value;
    const token = document.getElementById('verification-code').value;
    const button = document.getElementById('verify-btn');

    if (!phone || !token) {
        showMessage('verify-message', '请输入手机号和验证码', 'error');
        return;
    }

    try {
        // 确保Supabase客户端可用
        const supabase = ensureSupabaseClient();

        // 禁用按钮并显示加载状态
        button.disabled = true;
        button.textContent = '验证中...';

        // 验证验证码
        const { data, error } = await supabase.auth.verifyOtp({
            phone: phone,
            token: token,
            type: 'sms'
        });

        if (error) {
            showMessage('verify-message', `验证失败: ${error.message}`, 'error');
        } else {
            showMessage('verify-message', '验证成功！您已登录', 'success');
            // 显示用户信息
            showUserInfo(data);
        }
    } catch (error) {
        showMessage('verify-message', `验证失败: ${error.message}`, 'error');
    } finally {
        // 恢复按钮状态
        if (button) {
            button.disabled = false;
            button.textContent = '验证';
        }
    }
}

// 获取用户信息
async function getUserInfo() {
    try {
        // 确保Supabase客户端可用
        const supabase = ensureSupabaseClient();

        const { data: { user }, error } = await supabase.auth.getUser();

        if (error) {
            showMessage('user-info', `获取用户信息失败: ${error.message}`, 'error');
        } else if (user) {
            showUserInfo({ user });
        } else {
            showMessage('user-info', '未登录', 'info');
        }
    } catch (error) {
        showMessage('user-info', `获取用户信息失败: ${error.message}`, 'error');
    }
}

// 显示用户信息
function showUserInfo(data) {
    const userInfo = data.user;
    if (userInfo) {
        // 显示成功消息
        showMessage('user-info', '用户信息获取成功', 'success');

        // 显示详细用户信息表格
        const tableBody = document.getElementById('user-info-table-body');
        const jsonDiv = document.getElementById('user-info-json');
        const detailDiv = document.getElementById('user-info-detail');

        // 清空之前的内容
        tableBody.innerHTML = '';

        // 定义要显示的用户属性
        const userProperties = [
            { key: 'id', label: '用户ID' },
            { key: 'phone', label: '手机号' },
            { key: 'email', label: '邮箱' },
            { key: 'role', label: '角色' },
            { key: 'created_at', label: '创建时间' },
            { key: 'last_sign_in_at', label: '最后登录时间' },
            { key: 'confirmed_at', label: '确认时间' },
            { key: 'email_confirmed_at', label: '邮箱确认时间' },
            { key: 'phone_confirmed_at', label: '手机号确认时间' },
            { key: 'is_anonymous', label: '是否匿名用户' },
            { key: 'aud', label: '受众' },
            { key: 'updated_at', label: '更新时间' }
        ];

        // 填充表格数据
        userProperties.forEach(prop => {
            const value = userInfo[prop.key];
            const formattedValue = formatUserProperty(prop.key, value);

            const row = document.createElement('tr');
            row.innerHTML = `
                <td>${prop.label}</td>
                <td>${formattedValue}</td>
            `;
            tableBody.appendChild(row);
        });

        // 添加其他未列出的属性
        for (const key in userInfo) {
            // 跳过已经显示的属性
            if (userProperties.some(prop => prop.key === key)) {
                continue;
            }

            const value = userInfo[key];
            const formattedValue = formatUserProperty(key, value);

            const row = document.createElement('tr');
            row.innerHTML = `
                <td>${key}</td>
                <td>${formattedValue}</td>
            `;
            tableBody.appendChild(row);
        }

        // 显示原始JSON数据
        jsonDiv.textContent = JSON.stringify(userInfo, null, 2);

        // 显示详细信息区域
        detailDiv.classList.remove('hidden');
    }
}

// 格式化用户属性值
function formatUserProperty(key, value) {
    if (value === null || value === undefined) {
        return 'N/A';
    }

    // 处理日期字段
    if (key.includes('_at') && typeof value === 'string') {
        try {
            return new Date(value).toLocaleString();
        } catch (e) {
            return value;
        }
    }

    // 处理布尔值
    if (typeof value === 'boolean') {
        return value ? '是' : '否';
    }

    // 处理对象
    if (typeof value === 'object') {
        return JSON.stringify(value);
    }

    return value;
}

// 退出登录
async function signOut() {
    try {
        // 确保Supabase客户端可用
        const supabase = ensureSupabaseClient();

        const { error } = await supabase.auth.signOut();

        if (error) {
            showMessage('user-info', `退出失败: ${error.message}`, 'error');
        } else {
            showMessage('user-info', '已退出登录', 'success');
            // 清空用户信息显示
            setTimeout(() => {
                hideMessage('user-info');
            }, 2000);
        }
    } catch (error) {
        showMessage('user-info', `退出失败: ${error.message}`, 'error');
    }
}