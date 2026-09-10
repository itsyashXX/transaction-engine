export const apiClient = {
    async login(username: string, password: string) {
        const res = await fetch('/api/auth/login', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username, password })
        });
        if (!res.ok) throw new Error(await res.text());
        return res.json();
    },
    
    async requestTransaction(token: string, operation: string, amount_minor: number, idempotency_key: string) {
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
