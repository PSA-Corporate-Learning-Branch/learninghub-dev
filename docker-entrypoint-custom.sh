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
        --title="${WORDPRESS_TITLE:-Corporate Learning}" \
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

# Enable multisite if not already enabled
if ! wp core is-installed --network --allow-root --path=/var/www/html 2>/dev/null; then
    echo "Enabling WordPress multisite..."
    wp core multisite-convert --allow-root --path=/var/www/html
    echo "Multisite enabled!"

    # Setup .htaccess for multisite
    echo "Setting up .htaccess for multisite..."
    wp rewrite flush --allow-root --path=/var/www/html
    chown www-data:www-data /var/www/html/.htaccess 2>/dev/null || true

    # Ensure correct domain is set in wp-config.php
    echo "Configuring multisite domain..."
    wp config set DOMAIN_CURRENT_SITE localhost:8181 --allow-root --path=/var/www/html --type=constant
    wp config set PATH_CURRENT_SITE / --allow-root --path=/var/www/html --type=constant

    # Update main site URL to include port
    wp option update home "http://localhost:8181" --allow-root --path=/var/www/html
    wp option update siteurl "http://localhost:8181" --allow-root --path=/var/www/html

    # Update the main site domain in wp_blogs table to include port
    mysql --skip-ssl -h db -u wordpress -pwordpress wordpress -e "UPDATE wp_blogs SET domain='localhost:8181' WHERE blog_id=1;"

    # Update the network domain in wp_site table to include port
    mysql --skip-ssl -h db -u wordpress -pwordpress wordpress -e "UPDATE wp_site SET domain='localhost:8181' WHERE id=1;"

    echo ".htaccess and domain configured!"
else
    echo "Multisite already enabled."
fi

# Create mu-plugins directory and add multisite port fix
echo "Adding multisite port fix filter..."
mkdir -p /var/www/html/wp-content/mu-plugins
cat > /var/www/html/wp-content/mu-plugins/multisite-port-fix.php << 'EOF'
<?php
/**
 * Plugin Name: Multisite Port Fix
 * Description: Ensures custom ports are properly handled in multisite domains
 */

// Fix port in domain normalization
add_filter( 'wp_normalize_site_data', function( $data ) {
    if ( isset( $data['domain'] ) ) {
        // Ensure port 8181 has a colon before it
        $data['domain'] = str_replace( '8181', ':8181', $data['domain'] );
        // Prevent double colons
        $data['domain'] = str_replace( '::', ':', $data['domain'] );
    }
    return $data;
}, 50, 1 );

// Fix cookie domain to not include port
add_filter( 'site_url', function( $url, $path, $scheme, $blog_id ) {
    // Ensure URLs always have the port
    if ( strpos( $url, 'localhost' ) !== false && strpos( $url, ':8181' ) === false ) {
        $url = str_replace( 'localhost', 'localhost:8181', $url );
    }
    return $url;
}, 10, 4 );

add_filter( 'home_url', function( $url, $path, $orig_scheme, $blog_id ) {
    // Ensure URLs always have the port
    if ( strpos( $url, 'localhost' ) !== false && strpos( $url, ':8181' ) === false ) {
        $url = str_replace( 'localhost', 'localhost:8181', $url );
    }
    return $url;
}, 10, 4 );
EOF
chown www-data:www-data /var/www/html/wp-content/mu-plugins/multisite-port-fix.php
echo "Multisite port fix filter added!"

# Configure main site title and theme
echo "Configuring main site..."
wp option update blogname "Corporate Learning" --url="http://localhost:8181" --allow-root --path=/var/www/html
# Ensure main site uses a default theme (twentytwentyfour if available, otherwise twentytwentythree)
if wp theme is-installed twentytwentyfour --allow-root --path=/var/www/html 2>/dev/null; then
    wp theme activate twentytwentyfour --url="http://localhost:8181" --allow-root --path=/var/www/html 2>/dev/null || true
elif wp theme is-installed twentytwentythree --allow-root --path=/var/www/html 2>/dev/null; then
    wp theme activate twentytwentythree --url="http://localhost:8181" --allow-root --path=/var/www/html 2>/dev/null || true
fi

# Create network sites if they don't exist
# LearningHUB site
if ! wp site list --field=url --allow-root --path=/var/www/html 2>/dev/null | grep -q "learninghub"; then
    echo "Creating LearningHUB network site..."
    wp site create --slug=learninghub --title="LearningHUB" --email="${WORDPRESS_ADMIN_EMAIL:-admin@example.com}" --allow-root --path=/var/www/html
    echo "LearningHUB site created!"

    # Get the blog ID for the new site - find it from the blogs table
    SITE_ID=$(mysql --skip-ssl -h db -u wordpress -pwordpress wordpress -N -e "SELECT blog_id FROM wp_blogs WHERE path='/learninghub/' LIMIT 1;" | tr -d '\n\r ')

    # Update the domain in wp_blogs table to include the port
    echo "Fixing LearningHUB domain for site ID: $SITE_ID"
    mysql --skip-ssl -h db -u wordpress -pwordpress wordpress -e "UPDATE wp_blogs SET domain='localhost:8181' WHERE blog_id='$SITE_ID';"

    # Update the site's home and siteurl directly in the options table for that site
    # For site ID 1, the table is wp_options, for others it's wp_{ID}_options
    if [ "$SITE_ID" = "1" ]; then
        OPTIONS_TABLE="wp_options"
    else
        OPTIONS_TABLE="wp_${SITE_ID}_options"
    fi
    mysql --skip-ssl -h db -u wordpress -pwordpress wordpress -e "UPDATE $OPTIONS_TABLE SET option_value='http://localhost:8181/learninghub' WHERE option_name='home';"
    mysql --skip-ssl -h db -u wordpress -pwordpress wordpress -e "UPDATE $OPTIONS_TABLE SET option_value='http://localhost:8181/learninghub' WHERE option_name='siteurl';"
    echo "Updated domain in wp_blogs and URLs in $OPTIONS_TABLE"

    # Activate theme
    LEARNINGHUB_URL="http://localhost:8181/learninghub"
    wp theme enable wp-learninghub-theme --network --allow-root --path=/var/www/html 2>/dev/null || true
    wp theme activate wp-learninghub-theme --url="$LEARNINGHUB_URL" --allow-root --path=/var/www/html
    echo "LearningHUB theme activated!"
else
    echo "LearningHUB site already exists."
fi

# Learn @ Work Week 2025 site
if ! wp site list --field=url --allow-root --path=/var/www/html 2>/dev/null | grep -q "latww2025"; then
    echo "Creating Learn @ Work Week 2025 network site..."
    wp site create --slug=latww2025 --title="Learn @ Work Week 2025" --email="${WORDPRESS_ADMIN_EMAIL:-admin@example.com}" --allow-root --path=/var/www/html
    echo "Learn @ Work Week 2025 site created!"

    # Get the blog ID for the new site - find it from the blogs table
    SITE_ID=$(mysql --skip-ssl -h db -u wordpress -pwordpress wordpress -N -e "SELECT blog_id FROM wp_blogs WHERE path='/latww2025/' LIMIT 1;" | tr -d '\n\r ')

    # Update the domain in wp_blogs table to include the port
    echo "Fixing Learn @ Work Week 2025 domain for site ID: $SITE_ID"
    mysql --skip-ssl -h db -u wordpress -pwordpress wordpress -e "UPDATE wp_blogs SET domain='localhost:8181' WHERE blog_id='$SITE_ID';"

    # Update the site's home and siteurl directly in the options table for that site
    # For site ID 1, the table is wp_options, for others it's wp_{ID}_options
    if [ "$SITE_ID" = "1" ]; then
        OPTIONS_TABLE="wp_options"
    else
        OPTIONS_TABLE="wp_${SITE_ID}_options"
    fi
    mysql --skip-ssl -h db -u wordpress -pwordpress wordpress -e "UPDATE $OPTIONS_TABLE SET option_value='http://localhost:8181/latww2025' WHERE option_name='home';"
    mysql --skip-ssl -h db -u wordpress -pwordpress wordpress -e "UPDATE $OPTIONS_TABLE SET option_value='http://localhost:8181/latww2025' WHERE option_name='siteurl';"
    echo "Updated domain in wp_blogs and URLs in $OPTIONS_TABLE"

    # Activate theme
    LATWW_URL="http://localhost:8181/latww2025"
    wp theme enable wp-latww2025 --network --allow-root --path=/var/www/html 2>/dev/null || true
    wp theme activate wp-latww2025 --url="$LATWW_URL" --allow-root --path=/var/www/html
    echo "Learn @ Work Week 2025 theme activated!"
else
    echo "Learn @ Work Week 2025 site already exists."
fi

echo "Setup complete! WordPress is ready."

# Keep the WordPress process running
wait $WORDPRESS_PID
