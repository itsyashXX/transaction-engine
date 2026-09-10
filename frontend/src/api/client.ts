export const apiClient = {
    async login(username, password) {
        const res = await fetch('/api/auth/login', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username, password })
        });
        if (!res.ok) throw new Error(await res.text());
        return res.json();
    },
    
    async requestTransaction(token, operation, amount_minor, idempotency_key) {
        const res = await fetch('/api/transactions', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${token}`
            },
            body: JSON.stringify({ operation, amount_minor, idempotency_key })
        });
        if (!res.ok) throw new Error(await res.text());
        return res.json();
    }
}
