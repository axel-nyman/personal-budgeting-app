-- Users table
CREATE TABLE Users (
    UserID INT PRIMARY KEY AUTO_INCREMENT,
    Username VARCHAR(50) NOT NULL UNIQUE,
    PasswordHash VARCHAR(255) NOT NULL,
    Email VARCHAR(100) NOT NULL UNIQUE,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Groups to handle shared budgets and savings goals
CREATE TABLE Groups (
    GroupID INT PRIMARY KEY AUTO_INCREMENT,
    GroupName VARCHAR(100) NOT NULL,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User membership in groups
CREATE TABLE GroupMembers (
    GroupID INT,
    UserID INT,
    JoinedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (GroupID, UserID),
    FOREIGN KEY (GroupID) REFERENCES Groups(GroupID) ON DELETE CASCADE,
    FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE CASCADE
);

-- Categories for budgeting
CREATE TABLE Categories (
    CategoryID INT PRIMARY KEY AUTO_INCREMENT,
    Name VARCHAR(50) NOT NULL,
    Type ENUM('Income', 'Expense', 'Savings', 'OneOff') NOT NULL,
    Icon VARCHAR(50) NULL,
    Color VARCHAR(20) NULL
);

-- Bank accounts table
CREATE TABLE BankAccounts (
    AccountID INT PRIMARY KEY AUTO_INCREMENT,
    AccountName VARCHAR(50) NOT NULL,
    AccountNumber VARCHAR(50),
    BankName VARCHAR(50),
    InitialBalance DECIMAL(10, 2) DEFAULT 0.00,
    IsShared BOOLEAN DEFAULT FALSE,
    OwnerType ENUM('User', 'Group') NOT NULL,
    OwnerID INT NOT NULL,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    LastUpdated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX (OwnerType, OwnerID),
    CONSTRAINT CHK_Owner CHECK (
        (OwnerType = 'User' AND OwnerID IN (SELECT UserID FROM Users)) OR
        (OwnerType = 'Group' AND OwnerID IN (SELECT GroupID FROM Groups))
    )
);

-- Track account balances over time
CREATE TABLE AccountBalanceHistory (
    HistoryID INT PRIMARY KEY AUTO_INCREMENT,
    AccountID INT NOT NULL,
    Balance DECIMAL(10, 2) NOT NULL,
    RecordedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (AccountID) REFERENCES BankAccounts(AccountID) ON DELETE CASCADE
);

-- Monthly budgets
CREATE TABLE MonthlyBudgets (
    BudgetID INT PRIMARY KEY AUTO_INCREMENT,
    OwnerType ENUM('User', 'Group') NOT NULL,
    OwnerID INT NOT NULL,
    BudgetMonth DATE NOT NULL, -- Store as first day of month
    TotalIncome DECIMAL(10, 2) DEFAULT 0.00,
    TotalExpenses DECIMAL(10, 2) DEFAULT 0.00,
    TotalSavings DECIMAL(10, 2) DEFAULT 0.00,
    PersonalBudgetAmount DECIMAL(10, 2) DEFAULT 0.00,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    LastUpdated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX (OwnerType, OwnerID, BudgetMonth),
    CONSTRAINT CHK_MonthlyBudget_Owner CHECK (
        (OwnerType = 'User' AND OwnerID IN (SELECT UserID FROM Users)) OR
        (OwnerType = 'Group' AND OwnerID IN (SELECT GroupID FROM Groups))
    ),
    CONSTRAINT UC_MonthlyBudget UNIQUE (OwnerType, OwnerID, BudgetMonth)
);

-- Income items for monthly budgets
CREATE TABLE BudgetIncomes (
    IncomeID INT PRIMARY KEY AUTO_INCREMENT,
    BudgetID INT NOT NULL,
    CategoryID INT NOT NULL,
    AccountID INT,
    Amount DECIMAL(10, 2) NOT NULL,
    Description TEXT,
    IncomeDate DATE,
    IsRecurring BOOLEAN DEFAULT FALSE,
    RecurrenceType ENUM('Monthly', 'Quarterly', 'Biannual', 'Annual', 'Custom') NULL,
    RecurrenceInterval INT NULL, -- For custom recurrence (e.g., every X months)
    FOREIGN KEY (BudgetID) REFERENCES MonthlyBudgets(BudgetID) ON DELETE CASCADE,
    FOREIGN KEY (CategoryID) REFERENCES Categories(CategoryID),
    FOREIGN KEY (AccountID) REFERENCES BankAccounts(AccountID)
);

-- Expense items for monthly budgets
CREATE TABLE BudgetExpenses (
    ExpenseID INT PRIMARY KEY AUTO_INCREMENT,
    BudgetID INT NOT NULL,
    CategoryID INT NOT NULL,
    AccountID INT,
    Amount DECIMAL(10, 2) NOT NULL,
    Description TEXT,
    DueDate DATE,
    IsPaid BOOLEAN DEFAULT FALSE,
    IsRecurring BOOLEAN DEFAULT FALSE,
    RecurrenceType ENUM('Monthly', 'Quarterly', 'Biannual', 'Annual', 'Custom') NULL,
    RecurrenceInterval INT NULL, -- For custom recurrence (e.g., every X months)
    NextOccurrence DATE NULL,
    FOREIGN KEY (BudgetID) REFERENCES MonthlyBudgets(BudgetID) ON DELETE CASCADE,
    FOREIGN KEY (CategoryID) REFERENCES Categories(CategoryID),
    FOREIGN KEY (AccountID) REFERENCES BankAccounts(AccountID)
);

-- Savings goals
CREATE TABLE SavingsGoals (
    GoalID INT PRIMARY KEY AUTO_INCREMENT,
    OwnerType ENUM('User', 'Group') NOT NULL,
    OwnerID INT NOT NULL,
    GoalName VARCHAR(100) NOT NULL,
    TargetAmount DECIMAL(10, 2) NOT NULL,
    StartDate DATE NOT NULL,
    TargetDate DATE NOT NULL,
    Purpose VARCHAR(255),
    MonthlyContribution DECIMAL(10, 2) NULL,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    LastUpdated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX (OwnerType, OwnerID),
    CONSTRAINT CHK_SavingsGoal_Owner CHECK (
        (OwnerType = 'User' AND OwnerID IN (SELECT UserID FROM Users)) OR
        (OwnerType = 'Group' AND OwnerID IN (SELECT GroupID FROM Groups))
    )
);

-- Link bank accounts to savings goals
CREATE TABLE SavingsGoalAccounts (
    GoalID INT NOT NULL,
    AccountID INT NOT NULL,
    PRIMARY KEY (GoalID, AccountID),
    FOREIGN KEY (GoalID) REFERENCES SavingsGoals(GoalID) ON DELETE CASCADE,
    FOREIGN KEY (AccountID) REFERENCES BankAccounts(AccountID) ON DELETE CASCADE
);

-- Track savings progress over time
CREATE TABLE SavingsGoalHistory (
    HistoryID INT PRIMARY KEY AUTO_INCREMENT,
    GoalID INT NOT NULL,
    CurrentAmount DECIMAL(10, 2) NOT NULL,
    RecordedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (GoalID) REFERENCES SavingsGoals(GoalID) ON DELETE CASCADE
);

-- Budget savings allocations from monthly budgets
CREATE TABLE BudgetSavings (
    SavingsID INT PRIMARY KEY AUTO_INCREMENT,
    BudgetID INT NOT NULL,
    GoalID INT NOT NULL,
    Amount DECIMAL(10, 2) NOT NULL,
    AccountID INT,
    TransferDate DATE,
    IsTransferred BOOLEAN DEFAULT FALSE,
    Description TEXT,
    FOREIGN KEY (BudgetID) REFERENCES MonthlyBudgets(BudgetID) ON DELETE CASCADE,
    FOREIGN KEY (GoalID) REFERENCES SavingsGoals(GoalID) ON DELETE CASCADE,
    FOREIGN KEY (AccountID) REFERENCES BankAccounts(AccountID)
);

-- One-off budgets (for trips, projects, etc.)
CREATE TABLE OneOffBudgets (
    BudgetID INT PRIMARY KEY AUTO_INCREMENT,
    OwnerType ENUM('User', 'Group') NOT NULL,
    OwnerID INT NOT NULL,
    BudgetName VARCHAR(100) NOT NULL,
    TotalAmount DECIMAL(10, 2) NOT NULL,
    StartDate DATE NOT NULL,
    EndDate DATE,
    Purpose VARCHAR(255),
    LinkedGoalID INT NULL, -- If this budget is linked to a savings goal
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    LastUpdated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX (OwnerType, OwnerID),
    CONSTRAINT CHK_OneOffBudget_Owner CHECK (
        (OwnerType = 'User' AND OwnerID IN (SELECT UserID FROM Users)) OR
        (OwnerType = 'Group' AND OwnerID IN (SELECT GroupID FROM Groups))
    ),
    FOREIGN KEY (LinkedGoalID) REFERENCES SavingsGoals(GoalID)
);

-- Link bank accounts to one-off budgets
CREATE TABLE OneOffBudgetAccounts (
    BudgetID INT NOT NULL,
    AccountID INT NOT NULL,
    PRIMARY KEY (BudgetID, AccountID),
    FOREIGN KEY (BudgetID) REFERENCES OneOffBudgets(BudgetID) ON DELETE CASCADE,
    FOREIGN KEY (AccountID) REFERENCES BankAccounts(AccountID) ON DELETE CASCADE
);

-- One-off budget categories (custom categories for the specific budget)
CREATE TABLE OneOffBudgetCategories (
    CategoryID INT PRIMARY KEY AUTO_INCREMENT,
    BudgetID INT NOT NULL,
    CategoryName VARCHAR(50) NOT NULL,
    PlannedAmount DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (BudgetID) REFERENCES OneOffBudgets(BudgetID) ON DELETE CASCADE
);

-- One-off budget items
CREATE TABLE OneOffBudgetItems (
    ItemID INT PRIMARY KEY AUTO_INCREMENT,
    CategoryID INT NOT NULL,
    ItemName VARCHAR(100) NOT NULL,
    Description TEXT,
    FOREIGN KEY (CategoryID) REFERENCES OneOffBudgetCategories(CategoryID) ON DELETE CASCADE
);

-- Options for one-off budget items (e.g., different hotel options)
CREATE TABLE BudgetItemOptions (
    OptionID INT PRIMARY KEY AUTO_INCREMENT,
    ItemID INT NOT NULL,
    OptionName VARCHAR(100) NOT NULL,
    Price DECIMAL(10, 2) NOT NULL,
    Description TEXT,
    URL VARCHAR(255),
    IsSelected BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (ItemID) REFERENCES OneOffBudgetItems(ItemID) ON DELETE CASCADE
);

-- Transactions table to track actual money movement
CREATE TABLE Transactions (
    TransactionID INT PRIMARY KEY AUTO_INCREMENT,
    AccountID INT NOT NULL,
    CategoryID INT,
    Amount DECIMAL(10, 2) NOT NULL,
    Description TEXT,
    TransactionDate DATE NOT NULL,
    RelatedToType ENUM('Expense', 'Income', 'Savings', 'OneOffBudget') NULL,
    RelatedToID INT NULL, -- ID of the related expense, income, etc.
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (AccountID) REFERENCES BankAccounts(AccountID) ON DELETE CASCADE,
    FOREIGN KEY (CategoryID) REFERENCES Categories(CategoryID)
);

-- Notifications for upcoming expenses, goals, etc.
CREATE TABLE Notifications (
    NotificationID INT PRIMARY KEY AUTO_INCREMENT,
    UserID INT NOT NULL,
    Title VARCHAR(100) NOT NULL,
    Message TEXT NOT NULL,
    IsRead BOOLEAN DEFAULT FALSE,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE CASCADE
);

-- Triggers to maintain balances and history

-- Create history record whenever account balance is updated
DELIMITER //
CREATE TRIGGER after_account_update
AFTER UPDATE ON BankAccounts
FOR EACH ROW
BEGIN
    IF OLD.InitialBalance != NEW.InitialBalance THEN
        INSERT INTO AccountBalanceHistory (AccountID, Balance, RecordedAt)
        VALUES (NEW.AccountID, NEW.InitialBalance, NOW());
    END IF;
END //
DELIMITER ;

-- Create initial history record when account is created
DELIMITER //
CREATE TRIGGER after_account_insert
AFTER INSERT ON BankAccounts
FOR EACH ROW
BEGIN
    INSERT INTO AccountBalanceHistory (AccountID, Balance, RecordedAt)
    VALUES (NEW.AccountID, NEW.InitialBalance, NOW());
END //
DELIMITER ;

-- Update account balance after transaction
DELIMITER //
CREATE TRIGGER after_transaction_insert
AFTER INSERT ON Transactions
FOR EACH ROW
BEGIN
    UPDATE BankAccounts
    SET InitialBalance = InitialBalance + NEW.Amount
    WHERE AccountID = NEW.AccountID;
END //
DELIMITER ;

-- Update savings goal progress when related account balances change
DELIMITER //
CREATE PROCEDURE update_savings_goal_progress(IN goal_id INT)
BEGIN
    DECLARE total_amount DECIMAL(10, 2) DEFAULT 0.00;
    
    -- Calculate total from all linked accounts
    SELECT SUM(BA.InitialBalance) INTO total_amount
    FROM SavingsGoalAccounts SGA
    JOIN BankAccounts BA ON SGA.AccountID = BA.AccountID
    WHERE SGA.GoalID = goal_id;
    
    -- Record the progress
    INSERT INTO SavingsGoalHistory (GoalID, CurrentAmount)
    VALUES (goal_id, total_amount);
END //
DELIMITER ;

-- Create event to run the procedure daily for all goals
DELIMITER //
CREATE EVENT update_all_savings_goals
ON SCHEDULE EVERY 1 DAY
DO
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE goal_id INT;
    DECLARE cur CURSOR FOR SELECT GoalID FROM SavingsGoals;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    OPEN cur;
    read_loop: LOOP
        FETCH cur INTO goal_id;
        IF done THEN
            LEAVE read_loop;
        END IF;
        CALL update_savings_goal_progress(goal_id);
    END LOOP;
    CLOSE cur;
END //
DELIMITER ;