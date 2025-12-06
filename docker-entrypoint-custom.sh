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

# Configure WordPress for subdirectory installation
echo "Configuring WordPress for subdirectory /learninghub/..."
if ! grep -q "WP_SITEURL" /var/www/html/wp-config.php; then
    # Add subdirectory configuration to wp-config.php
    sed -i "/\/\* That's all, stop editing!/i \
/* Subdirectory configuration */\n\
define('WP_SITEURL', 'http://localhost:8181/learninghub');\n\
define('WP_HOME', 'http://localhost:8181/learninghub');\n" /var/www/html/wp-config.php
    echo "Added subdirectory configuration to wp-config.php"
fi

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

# Install themes from GitHub
if [ ! -d "/var/www/html/wp-content/themes/wp-learninghub-theme" ]; then
    echo "Installing Learning Hub theme from GitHub..."
    cd /var/www/html/wp-content/themes
    git clone https://github.com/PSA-Corporate-Learning-Branch/wp-learninghub-theme.git
    chown -R www-data:www-data wp-learninghub-theme
    echo "Learning Hub theme installed!"
else
    echo "Learning Hub theme already installed."
fi

if [ ! -d "/var/www/html/wp-content/themes/wp-latww2025" ]; then
    echo "Installing Learn @ Work Week 2025 theme from GitHub..."
    cd /var/www/html/wp-content/themes
    git clone https://github.com/PSA-Corporate-Learning-Branch/wp-latww2025.git
    chown -R www-data:www-data wp-latww2025
    echo "Learn @ Work Week 2025 theme installed!"
else
    echo "Learn @ Work Week 2025 theme already installed."
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

# Install WordPress Importer plugin
if ! wp plugin is-installed wordpress-importer --allow-root --path=/var/www/html 2>/dev/null; then
    echo "Installing WordPress Importer plugin..."
    wp plugin install wordpress-importer --activate --allow-root --path=/var/www/html
    echo "WordPress Importer plugin installed and activated!"
else
    echo "WordPress Importer plugin already installed."
    # Ensure it's activated
    if ! wp plugin is-active wordpress-importer --allow-root --path=/var/www/html 2>/dev/null; then
        echo "Activating WordPress Importer plugin..."
        wp plugin activate wordpress-importer --allow-root --path=/var/www/html
    fi
fi

# Activate Learning Hub theme
echo "Activating Learning Hub theme..."
wp theme activate wp-learninghub-theme --allow-root --path=/var/www/html 2>/dev/null || true

# Configure permalinks for pretty URLs
echo "Configuring pretty permalinks..."
wp rewrite structure '/%postname%/' --allow-root --path=/var/www/html
wp rewrite flush --allow-root --path=/var/www/html

# Fix .htaccess for subdirectory - WordPress doesn't generate this correctly
cat > /var/www/html/.htaccess << 'EOF'
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
EOF

chown www-data:www-data /var/www/html/.htaccess
echo "Permalinks configured!"

# Import content if XML file exists
if [ -f "/var/www/html/learninghub.WordPress-latest.xml" ]; then
    echo "Found learninghub.WordPress-latest.xml, importing content (skipping attachments)..."
    wp import /var/www/html/learninghub.WordPress-latest.xml \
        --authors=create \
        --skip=attachment \
        --allow-root \
        --path=/var/www/html
    echo "Content import complete!"
else
    echo "No learninghub.WordPress-latest.xml found, skipping import."
fi

echo "Setup complete! WordPress is ready at http://localhost:8181/learninghub/"
echo "Login credentials: admin / admin"

# Keep the WordPress process running
wait $WORDPRESS_PID
