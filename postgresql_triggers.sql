CREATE TABLE users (
    id serial,
    username text,
    salary integer
);

CREATE TABLE carts (
    id serial,
    user_id integer,
    sum integer
);

create table products_cart (
    product_id integer,
    cart_id integer,
    quantity integer,
    total integer
);

create table products (
    id serial,
    title varchar(255),
    price integer,
    in_stock integer
);

-- При создании записи в cart_products считаем стоимость, проверяем остатки

drop trigger if exists check_products_cart_tg on public.products_cart;
drop function if exists check_products_cart();
create function check_products_cart() returns trigger as $$
    declare
        product products%rowtype;

    begin
        select * into product from products where id = new.product_id;
--         Проверка на существование товара
        if product is null then
            raise exception 'Product with id = % not found', new.product_id;
        end if;
--         Проверка на наличие корзины
        if (select id from carts where id = new.cart_id) is null then
            raise exception 'Cart with id = % not found', new.cart_id;
        end if;
--         Проверка на наличие достаточного количества товара
        if new.quantity > (product.in_stock) then
            raise exception 'There are only % of % on stock', product.in_stock, product.title;
        end if;
--         Выбрали цену товара, умножили на количество
        new.total = (product.price * new.quantity);

        return new;
    end;
$$ language plpgsql;

create trigger check_products_cart_tg
    before insert or update
    on products_cart
    for each row execute procedure check_products_cart();


-- При изменении цены на товар, пересчитываем корзины
drop trigger if exists check_products_tg on public.products;
drop function if exists check_products();
create function check_products() returns trigger as $$
declare

begin
    update products_cart pc
    set total = new.price * pc.quantity
    where pc.product_id = new.id;

    return new;
end;
$$ language plpgsql;

create trigger check_products_tg
    after update
    on products
    for each row execute procedure check_products();


drop trigger if exists cart_sum_process_tg on public.products_cart;
drop function if exists cart_sum_process();
create function cart_sum_process() returns trigger as $$
    begin
        update carts
        set sum = (select sum(total) from products_cart where cart_id = new.cart_id group by cart_id)
        where id = new.cart_id;

        return new;
    end;
$$ language plpgsql;

create trigger cart_sum_process_tg
    after insert or update
    on products_cart
    for each row execute procedure cart_sum_process();



