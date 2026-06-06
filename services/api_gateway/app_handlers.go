package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/gofiber/fiber/v2"
)

// ─── App Update Handlers ────────────────────────────────────────────────────

// AppVersion holds the metadata for a single release.
type AppVersion struct {
	Version      string `json:"version"`
	BuildNumber  int    `json:"build_number"`
	DownloadURL  string `json:"download_url"`
	ReleaseNotes string `json:"release_notes"`
	ForceUpdate  bool   `json:"force_update"`
	FileSize     int64  `json:"file_size"`
}

// handleAppVersion returns the latest app version metadata.
// GET /api/v1/app/version
//
// The handler reads data/releases/version.json which is a simple JSON file
// you maintain alongside the APK. Example:
//
//	{
//	  "version": "0.2.0",
//	  "build_number": 2,
//	  "download_url": "/api/v1/app/download/superapp-v0.2.0.apk",
//	  "release_notes": "• New scholarship alerts\n• Bug fixes",
//	  "force_update": false
//	}
//
// The download_url can be absolute or relative (relative URLs are resolved
// against the request host).
func handleAppVersion(c *fiber.Ctx) error {
	releasesDir := os.Getenv("RELEASES_DIR")
	if releasesDir == "" {
		releasesDir = filepath.Join("data", "releases")
	}

	versionFile := filepath.Join(releasesDir, "version.json")

	data, err := os.ReadFile(versionFile)
	if err != nil {
		if os.IsNotExist(err) {
			return c.Status(404).JSON(fiber.Map{
				"error": "no releases available",
			})
		}
		log.Printf("WARN: failed to read version.json: %v", err)
		return c.Status(500).JSON(fiber.Map{
			"error": "failed to read version info",
		})
	}

	var ver AppVersion
	if err := json.Unmarshal(data, &ver); err != nil {
		log.Printf("WARN: invalid version.json: %v", err)
		return c.Status(500).JSON(fiber.Map{
			"error": "invalid version info",
		})
	}

	// Resolve relative download URLs against the request host.
	if ver.DownloadURL != "" && !strings.HasPrefix(ver.DownloadURL, "http") {
		scheme := "http"
		if c.Get("X-Forwarded-Proto") == "https" {
			scheme = "https"
		}
		ver.DownloadURL = scheme + "://" + c.Hostname() + ver.DownloadURL
	}

	// Auto-populate file_size from the APK on disk.
	if ver.FileSize == 0 && ver.DownloadURL != "" {
		// Extract filename from the download URL.
		parts := strings.Split(ver.DownloadURL, "/")
		if len(parts) > 0 {
			apkPath := filepath.Join(releasesDir, parts[len(parts)-1])
			if info, err := os.Stat(apkPath); err == nil {
				ver.FileSize = info.Size()
			}
		}
	}

	return c.JSON(ver)
}

// handleAppDownload serves APK files from the releases directory.
// GET /api/v1/app/download/:filename
func handleAppDownload(c *fiber.Ctx) error {
	filename := c.Params("filename")
	if filename == "" {
		return c.Status(400).JSON(fiber.Map{"error": "filename is required"})
	}

	// Security: prevent directory traversal.
	if strings.Contains(filename, "..") || strings.Contains(filename, "/") || strings.Contains(filename, "\\") {
		return c.Status(400).JSON(fiber.Map{"error": "invalid filename"})
	}

	releasesDir := os.Getenv("RELEASES_DIR")
	if releasesDir == "" {
		releasesDir = filepath.Join("data", "releases")
	}

	filePath := filepath.Join(releasesDir, filename)

	// Check file exists.
	info, err := os.Stat(filePath)
	if err != nil {
		if os.IsNotExist(err) {
			return c.Status(404).JSON(fiber.Map{"error": "file not found"})
		}
		return c.Status(500).JSON(fiber.Map{"error": "failed to access file"})
	}

	// Set headers for APK download.
	c.Set("Content-Type", "application/vnd.android.package-archive")
	c.Set("Content-Disposition", fmt.Sprintf("attachment; filename=\"%s\"", filename))
	c.Set("Content-Length", fmt.Sprintf("%d", info.Size()))

	return c.SendFile(filePath)
}
