directory_1920x1080=~/Pictures/Wallpaper/1920x1080
directory_1080x2400=~/Pictures/Wallpaper/1080x2400
config_file=~/.config/hypr/hyprpaper.conf

random_background_1920=$(find "$directory_1920x1080" -type f \( -name '*.jpg' -o -name '*.png' \) | shuf -n 1)
random_background_1080=$(find "$directory_1080x2400" -type f \( -name '*.jpg' -o -name '*.png' \) | shuf -n 1)
echo "preload = $random_background_1920" > "$config_file"
echo "preload = $random_background_1080" >> "$config_file"
echo "wallpaper = DP-5, $random_background_1920" >> "$config_file"
echo "wallpaper = HDMI-A-1, $random_background_1920" >> "$config_file"
echo "wallpaper = DP-4, $random_background_1080" >> "$config_file"
sed -i "s|background-image:.*|background-image: url(\"$random_background_1920\", height);|" ~/.config/rofi/style-2.rasi	
