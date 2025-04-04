-- Users table to store user information
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Groups table to handle shared budgets/goals
CREATE TABLE groups (
    group_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User-Group relationship (many-to-many)
CREATE TABLE user_groups (
    user_id INTEGER REFERENCES users(user_id) ON DELETE CASCADE,
    group_id INTEGER REFERENCES groups(group_id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, group_id)
);

-- Bank accounts table
CREATE TABLE bank_accounts (
    account_id SERIAL PRIMARY KEY,
    account_name VARCHAR(100) NOT NULL,
    current_balance DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    account_type VARCHAR(50) NOT NULL, -- checking, savings, etc.
    is_shared BOOLEAN NOT NULL DEFAULT FALSE,
    user_id INTEGER REFERENCES users(user_id),
    group_id INTEGER REFERENCES groups(group_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- Account must belong to either a user OR a group, not both
    CONSTRAINT account_owner_check CHECK (
        (user_id IS NULL AND group_id IS NOT NULL) OR
        (user_id IS NOT NULL AND group_id IS NULL)
    )
);

-- Account balance history for tracking over time
CREATE TABLE account_balance_history (
    history_id SERIAL PRIMARY KEY,
    account_id INTEGER REFERENCES bank_accounts(account_id) ON DELETE CASCADE,
    balance DECIMAL(12,2) NOT NULL,
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Monthly budgets
CREATE TABLE monthly_budgets (
    budget_id SERIAL PRIMARY KEY,
    budget_name VARCHAR(100) NOT NULL,
    year INTEGER NOT NULL,
    month INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
    is_shared BOOLEAN NOT NULL DEFAULT FALSE,
    user_id INTEGER REFERENCES users(user_id),
    group_id INTEGER REFERENCES groups(group_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- Budget must belong to either a user OR a group, not both
    CONSTRAINT budget_owner_check CHECK (
        (user_id IS NULL AND group_id IS NOT NULL) OR
        (user_id IS NOT NULL AND group_id IS NULL)
    ),
    -- Enforce only one monthly budget per user/group
    CONSTRAINT unique_monthly_budget UNIQUE (year, month, user_id, group_id)
);

-- Income sources
CREATE TABLE income_sources (
    income_id SERIAL PRIMARY KEY,
    budget_id INTEGER REFERENCES monthly_budgets(budget_id) ON DELETE CASCADE,
    description VARCHAR(255) NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    account_id INTEGER REFERENCES bank_accounts(account_id),
    income_date DATE NOT NULL,
    is_recurring BOOLEAN NOT NULL DEFAULT FALSE,
    recurrence_type VARCHAR(20), -- monthly, yearly, custom
    recurrence_interval INTEGER, -- every X months/years
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Expense categories
CREATE TABLE expense_categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    is_shared BOOLEAN NOT NULL DEFAULT TRUE,
    user_id INTEGER REFERENCES users(user_id),
    group_id INTEGER REFERENCES groups(group_id),
    CONSTRAINT category_owner_check CHECK (
        (user_id IS NULL AND group_id IS NOT NULL) OR
        (user_id IS NOT NULL AND group_id IS NULL)
    )
);

-- Expenses
CREATE TABLE expenses (
    expense_id SERIAL PRIMARY KEY,
    budget_id INTEGER REFERENCES monthly_budgets(budget_id) ON DELETE CASCADE,
    category_id INTEGER REFERENCES expense_categories(category_id),
    description VARCHAR(255) NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    expense_date DATE NOT NULL,
    account_id INTEGER REFERENCES bank_accounts(account_id),
    is_recurring BOOLEAN NOT NULL DEFAULT FALSE,
    is_paid BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Recurring expenses pattern (for expenses that repeat)
CREATE TABLE recurring_expenses (
    recurring_id SERIAL PRIMARY KEY,
    first_expense_id INTEGER REFERENCES expenses(expense_id) ON DELETE CASCADE,
    description VARCHAR(255) NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    category_id INTEGER REFERENCES expense_categories(category_id),
    account_id INTEGER REFERENCES bank_accounts(account_id),
    recurrence_type VARCHAR(20) NOT NULL, -- monthly, yearly, custom
    recurrence_interval INTEGER NOT NULL DEFAULT 1, -- every X months/years
    start_date DATE NOT NULL,
    end_date DATE, -- NULL means indefinite
    user_id INTEGER REFERENCES users(user_id),
    group_id INTEGER REFERENCES groups(group_id),
    CONSTRAINT recurring_owner_check CHECK (
        (user_id IS NULL AND group_id IS NOT NULL) OR
        (user_id IS NOT NULL AND group_id IS NULL)
    ),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Savings allocations within monthly budget
CREATE TABLE savings_allocations (
    allocation_id SERIAL PRIMARY KEY,
    budget_id INTEGER REFERENCES monthly_budgets(budget_id) ON DELETE CASCADE,
    account_id INTEGER REFERENCES bank_accounts(account_id),
    amount DECIMAL(12,2) NOT NULL,
    description VARCHAR(255),
    allocation_date DATE NOT NULL,
    is_transferred BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Personal budget allocations
CREATE TABLE personal_allocations (
    allocation_id SERIAL PRIMARY KEY,
    budget_id INTEGER REFERENCES monthly_budgets(budget_id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(user_id) NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    account_id INTEGER REFERENCES bank_accounts(account_id),
    allocation_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Savings goals table (for future implementation)
CREATE TABLE savings_goals (
    goal_id SERIAL PRIMARY KEY,
    goal_name VARCHAR(100) NOT NULL,
    target_amount DECIMAL(12,2) NOT NULL,
    current_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    target_date DATE,
    is_shared BOOLEAN NOT NULL DEFAULT FALSE,
    user_id INTEGER REFERENCES users(user_id),
    group_id INTEGER REFERENCES groups(group_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT goal_owner_check CHECK (
        (user_id IS NULL AND group_id IS NOT NULL) OR
        (user_id IS NOT NULL AND group_id IS NULL)
    )
);

-- Relationships between bank accounts and savings goals
CREATE TABLE goal_accounts (
    goal_id INTEGER REFERENCES savings_goals(goal_id) ON DELETE CASCADE,
    account_id INTEGER REFERENCES bank_accounts(account_id) ON DELETE CASCADE,
    PRIMARY KEY (goal_id, account_id)
);

-- View to calculate remaining budget after expenses
CREATE VIEW budget_summary AS
SELECT 
    mb.budget_id, 
    mb.budget_name,
    mb.year,
    mb.month,
    COALESCE(SUM(i.amount), 0) as total_income,
    COALESCE(SUM(e.amount), 0) as total_expenses,
    COALESCE(SUM(i.amount), 0) - COALESCE(SUM(e.amount), 0) as remaining_budget,
    COALESCE(SUM(sa.amount), 0) as total_savings,
    COALESCE(SUM(i.amount), 0) - COALESCE(SUM(e.amount), 0) - COALESCE(SUM(sa.amount), 0) as personal_budget_total
FROM 
    monthly_budgets mb
LEFT JOIN 
    income_sources i ON mb.budget_id = i.budget_id
LEFT JOIN 
    expenses e ON mb.budget_id = e.budget_id
LEFT JOIN 
    savings_allocations sa ON mb.budget_id = sa.budget_id
GROUP BY 
    mb.budget_id, mb.budget_name, mb.year, mb.month;