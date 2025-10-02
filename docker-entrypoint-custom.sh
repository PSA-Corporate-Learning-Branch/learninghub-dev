#!/bin/bash
set -e

# First, run the original WordPress entrypoint in the background
docker-entrypoint.sh apache2-foreground &
WORDPRESS_PID=$!

# Wait for WordPress files to be ready
echo "Waiting for WordPress files..."
until [ -f /var/www/html/wp-config.php ]; do
    sleep 2
done

echo "WordPress files ready, waiting for database..."
# Simple wait - just give the database time to fully start
sleep 10
echo "Database should be ready now!"

# Check if WordPress is installed
if ! wp core is-installed --allow-root --path=/var/www/html 2>/dev/null; then
    echo "Installing WordPress core..."
    wp core install \
        --url="${WORDPRESS_URL:-http://localhost:8181}" \
        --title="${WORDPRESS_TITLE:-Learning Hub}" \
        --admin_user="${WORDPRESS_ADMIN_USER:-admin}" \
        --admin_password="${WORDPRESS_ADMIN_PASSWORD:-admin}" \
        --admin_email="${WORDPRESS_ADMIN_EMAIL:-admin@example.com}" \
        --allow-root \
        --path=/var/www/html
    echo "WordPress core installed!"
else
    echo "WordPress core already installed."
fi

# Install theme from GitHub
if [ ! -d "/var/www/html/wp-content/themes/wp-learninghub-theme" ]; then
    echo "Installing Learning Hub theme from GitHub..."
    cd /var/www/html/wp-content/themes
    git clone https://github.com/PSA-Corporate-Learning-Branch/wp-learninghub-theme.git
    chown -R www-data:www-data wp-learninghub-theme
    echo "Activating Learning Hub theme..."
    wp theme activate wp-learninghub-theme --allow-root --path=/var/www/html
    echo "Theme installed and activated!"
else
    echo "Learning Hub theme already installed."
fi

# Install plugin from GitHub
if [ ! -d "/var/www/html/wp-content/plugins/wp-learninghub-plugin" ]; then
    echo "Installing Learning Hub plugin from GitHub..."
    cd /var/www/html/wp-content/plugins
    git clone https://github.com/PSA-Corporate-Learning-Branch/wp-learninghub-plugin.git
    chown -R www-data:www-data wp-learninghub-plugin
    echo "Activating Learning Hub plugin..."
    wp plugin activate wp-learninghub-plugin --allow-root --path=/var/www/html
    echo "Plugin installed and activated!"
else
    echo "Learning Hub plugin already installed."
fi

echo "Setup complete! WordPress is ready."

# Keep the WordPress process running
wait $WORDPRESS_PID
