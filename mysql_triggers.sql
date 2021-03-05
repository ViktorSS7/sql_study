# Create table
Create table customers (
    customer_id BIGINT PRIMARY KEY,
    customer_name VARCHAR(50),
    level VARCHAR(50)
) ENGINE=INNODB;



# Insert customers
Insert into customers
    (customer_id, customer_name, level )
values
    ('1','JOHN DOE','BASIC');

Insert into customers
    (customer_id, customer_name, level )
values
    ('2','MARY ROE','BASIC');

Insert into customers
    (customer_id, customer_name, level )
values
    ('3','JOHN DOE','VIP');



# Create Customer_status table
Create table customer_status (
    customer_id BIGINT PRIMARY KEY,
    status_notes VARCHAR(50)
) ENGINE=INNODB;


# Create table sales
Create table sales (
    sales_id BIGINT PRIMARY KEY,
    customer_id BIGINT,
    sales_amount DOUBLE
) ENGINE=INNODB;


# Create table for logs
Create table audit_log (
    log_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    sales_id BIGINT,
    previous_amount DOUBLE,
    new_amount DOUBLE,
    updated_by VARCHAR(50),
    updated_on DATETIME
) ENGINE=INNODB;

# Запрещаем продажи на > 10000
CREATE TRIGGER validate_sales_amount
BEFORE INSERT
ON sales
FOR EACH ROW
    IF NEW.sales_amount>10000 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Sale has exceeded the allowed amount of 10000.';
    END IF;
DELIMITER ;


# Добавляем статусы пользователю при создании
CREATE TRIGGER customer_status_records
AFTER INSERT
ON customers
FOR EACH ROW
    Insert into customer_status
        (customer_id, status_notes)
    VALUES
        (NEW.customer_id, 'ACCOUNT OPENED SUCCESSFULLY');
DELIMITER ;


# Запрещаем понижать уровень VIP пользователям
CREATE TRIGGER validate_customer_level
BEFORE UPDATE
ON customers
FOR EACH ROW
    IF OLD.level='VIP' AND NEW.level <> 'VIP' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'A VIP customer can not be downgraded.';
    END IF;
DELIMITER ;


# Логируем обновления продаж
CREATE TRIGGER log_sales_updates
AFTER UPDATE
ON sales
FOR EACH ROW
    Insert into audit_log
        (sales_id, previous_amount, new_amount, updated_by, updated_on)
        VALUES
        (NEW.sales_id,OLD.sales_amount, NEW.sales_amount,(SELECT USER()), NOW() );
DELIMITER ;

# Запрещаем удалять пользователей у которых есть продажи
CREATE TRIGGER validate_related_records
BEFORE DELETE
ON customers
FOR EACH ROW
    IF OLD.customer_id in (select customer_id from sales) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'The customer has a related sales record.';
    END IF;
DELIMITER ;


# Удаляем клиента после удаления всех его продаж
CREATE TRIGGER delete_related_info
AFTER DELETE
ON sales
FOR EACH ROW
    IF (
        SELECT customer_id from sales WHERE customer_id = OLD.customer_id
    ) is null then
        Delete from customers where customer_id=OLD.customer_id;
    END IF;
DELIMITER ;


# Удаляем тригер проверки цены
DROP TRIGGER validate_sales_amount
